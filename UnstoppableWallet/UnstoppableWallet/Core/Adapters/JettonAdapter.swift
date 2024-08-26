import BigInt
import Combine
import Foundation
import HdWalletKit
import HsToolKit
import MarketKit
import RxSwift
import TonKit
import TonSwift
import TweetNacl

class JettonAdapter {
    private let tonKit: TonKit.Kit
    private let ownAddress: TonSwift.Address
    private let jettonInfo: JettonInfo

    private let transactionSource: TransactionSource
    private let jettonToken: Token
    private let baseToken: Token
    private let reachabilityManager = App.shared.reachabilityManager
    private let appManager = App.shared.appManager

    private var cancellables = Set<AnyCancellable>()

    private var adapterStarted = false
    private var kitStarted = false

    private let logger: Logger?

    private let adapterStateSubject = PublishSubject<AdapterState>()
    private(set) var adapterState: AdapterState {
        didSet {
            adapterStateSubject.onNext(adapterState)
        }
    }

    private let balanceDataSubject = PublishSubject<BalanceData>()
    private(set) var balanceData = BalanceData(available: 0) {
        didSet {
            balanceDataSubject.onNext(balanceData)
        }
    }

    private let transactionRecordsSubject = PublishSubject<[TonTransactionRecord]>()

    init(tonKit: TonKit.Kit, wallet: Wallet, baseToken: Token) throws {
        guard case let .jetton(address) = wallet.token.type else {
            throw JettonAdapter.AdapterError.wrongTokenType
        }

        guard let tokenAddress = try? FriendlyAddress(string: address) else {
            throw JettonAdapter.AdapterError.wrongJettonAddress
        }
        transactionSource = wallet.transactionSource

        self.baseToken = baseToken
        
        jettonToken = wallet.token
        jettonInfo = JettonInfo(
            address: tokenAddress.address,
            fractionDigits: wallet.token.decimals,
            name: wallet.coin.name,
            symbol: wallet.coin.code,
            verification: .none,
            imageURL: URL(string: wallet.coin.imageUrl)
        )

//        logger = Logger(minLogLevel: .debug)
        logger = App.shared.logger.scoped(with: "TonKit")
        self.tonKit = tonKit
        
        ownAddress = tonKit.address
        adapterState = Self.adapterState(kitSyncState: tonKit.syncState)

        tonKit.syncStatePublisher
            .sink { [weak self] syncState in
                self?.adapterState = Self.adapterState(kitSyncState: syncState)
            }
            .store(in: &cancellables)

        tonKit.jettonBalancePublisher(address: jettonInfo.address)
            .sink { [weak self] balance in
                self?.updateBalanceData(balance: balance)
            }
            .store(in: &cancellables)
        
        updateBalanceData(balance: tonKit.jettonBalance(address: jettonInfo.address))
    }
    
    private func updateBalanceData(balance: BigUInt) {
        balanceData = BalanceData(available: Self.amount(kitAmount: balance, decimals: jettonToken.decimals))
    }

    private func handle(tonTransactions: [TonKit.FullTransaction]) {
        let transactionRecords = tonTransactions.map { transactionRecord(tonTransaction: $0) }
        transactionRecordsSubject.onNext(transactionRecords)
    }

    private static func adapterState(kitSyncState: TonKit.SyncState) -> AdapterState {
        switch kitSyncState {
        case .syncing: return .syncing(progress: nil, lastBlockDate: nil)
        case .synced: return .synced
        case let .notSynced(error): return .notSynced(error: error)
        }
    }

    static func amount(kitAmount: String, decimals: Int) -> Decimal {
        Decimal(string: kitAmount).map { Self.amount(kitAmount: $0, decimals: decimals) } ?? 0
    }

    static func amount(kitAmount: BigUInt, decimals: Int) -> Decimal {
        amount(kitAmount: kitAmount.toDecimal(decimals: 0) ?? 0, decimals: decimals)
    }

    static func amount(kitAmount: Decimal, decimals: Int) -> Decimal {
        kitAmount / pow(10, decimals)
    }

    private func transactionRecord(tonTransaction tx: TonKit.FullTransaction) -> TonTransactionRecord {
        switch tx.decoration {
        case is TonKit.IncomingJettonDecoration:
            return JettonIncomingTransactionRecord(
                source: .init(blockchainType: .ton, meta: nil),
                event: tx.event,
                feeToken: baseToken,
                token: jettonToken
            )

        case let decoration as TonKit.OutgoingJettonDecoration:
            return JettonOutgoingTransactionRecord(
                source: .init(blockchainType: .ton, meta: nil),
                event: tx.event,
                feeToken: baseToken,
                token: jettonToken,
                sentToSelf: decoration.sentToSelf
            )

        default:
            return TonTransactionRecord(
                source: .init(blockchainType: .ton, meta: nil),
                event: tx.event,
                feeToken: baseToken
            )
        }
    }

    private func tagQuery(token _: MarketKit.Token?, filter: TransactionTypeFilter, address: String?) -> TransactionTagQuery {
        var type: TransactionTag.TagType?

        switch filter {
        case .all: ()
        case .incoming: type = .incoming
        case .outgoing: type = .outgoing
        case .swap: type = .swap
        case .approve: type = .approve
        }

        return TransactionTagQuery(type: type, protocol: .jetton, jettonAddress: jettonInfo.address, address: address)
    }

    private func startKit() {
        logger?.log(level: .debug, message: "JettonAdapter, start kit.")
        tonKit.start()
        kitStarted = true
    }

    private func stopKit() {
        logger?.log(level: .debug, message: "JettonAdapter, stop kit.")
        tonKit.stop()
        kitStarted = false
    }
}

extension JettonAdapter: IBaseAdapter {
    var isMainNet: Bool {
        true
    }
}

extension JettonAdapter: IAdapter {
    func start() {
        adapterStarted = true

        if reachabilityManager.isReachable {
            startKit()
        }
    }

    func stop() {
        adapterStarted = false

        if kitStarted {
            stopKit()
        }
    }

    func refresh() {
        tonKit.refresh()
    }

    var statusInfo: [(String, Any)] {
        [] // tonKit.statusInfo()
    }

    var debugInfo: String {
        ""
    }
}

extension JettonAdapter: IBalanceAdapter {
    var balanceStateUpdatedObservable: Observable<AdapterState> {
        adapterStateSubject
    }

    var balanceDataUpdatedObservable: Observable<BalanceData> {
        balanceDataSubject.asObservable()
    }

    var balanceState: AdapterState {
        adapterState
    }
}

extension JettonAdapter: IDepositAdapter {
    var receiveAddress: DepositAddress {
        DepositAddress(tonKit.receiveAddress.toString(bounceable: TonAdapter.bounceableDefault))
    }
}

extension JettonAdapter: ISendTonAdapter {
    var availableBalance: Decimal {
        balanceData.available
    }

    func validate(address: String) throws {
        _ = try FriendlyAddress(string: address)
    }

    func estimateFee(recipient: String, amount: Decimal, memo: String?) async throws -> Decimal {
        let amount = amount.rounded(decimal: jettonToken.decimals)
        guard let jetton = tonKit.jettons.first(where: { $0.address == jettonInfo.address }) else {
            throw AdapterError.cantCreateJetton
        }

        let kitAmount = try await tonKit.estimateFee(recipient: recipient, jetton: jetton, amount: BigUInt(amount.description) ?? 0, comment: memo)
        return Self.amount(kitAmount: kitAmount, decimals: jettonToken.decimals)
    }

    func send(recipient: String, amount: Decimal, memo: String?) async throws {
        let amount = amount.rounded(decimal: jettonToken.decimals)
        guard let jetton = tonKit.jettons.first(where: { $0.address == jettonInfo.address }) else {
            throw AdapterError.cantCreateJetton
        }

        try await tonKit.send(recipient: recipient, jetton: jetton, amount: BigUInt(amount.description) ?? 0, comment: memo)
    }
}

extension JettonAdapter {
    enum AdapterError: Error {
        case wrongTokenType
        case wrongJettonAddress
        case cantCreateJetton
    }
}
