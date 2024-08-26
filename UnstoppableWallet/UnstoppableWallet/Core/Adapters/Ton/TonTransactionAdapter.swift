import BigInt
import Foundation
import HsToolKit
import MarketKit
import RxSwift
import UniswapKit
import TonKit
import TonSwift

class TonTransactionsAdapter: TonAdapter {
    private let transactionSource: TransactionSource
    private let transactionConverter: TonTransactionConverter

    init(tonKit: TonKit.Kit, source: TransactionSource, baseToken: MarketKit.Token, coinManager: CoinManager) {
        self.transactionSource = source
        transactionConverter = TonTransactionConverter(source: source, baseToken: baseToken, coinManager: coinManager, tonKit: tonKit)

        super.init(tonKit: tonKit, token: baseToken)
    }

    private func tagQuery(token: MarketKit.Token?, filter: TransactionTypeFilter, address: String?) -> TransactionTagQuery {
        var type: TransactionTag.TagType?
        var `protocol`: TransactionTag.TagProtocol?
        var jettonAddress: TonSwift.Address?

        if let token {
            switch token.type {
            case .native:
                `protocol` = .native
            case let .jetton(address):
                if let address = try? FriendlyAddress.init(string: address) {
                    `protocol` = .jetton
                    jettonAddress = address.address
                }
            default: ()
            }
        }

        switch filter {
        case .all: ()
        case .incoming: type = .incoming
        case .outgoing: type = .outgoing
        case .swap: type = .swap
        case .approve: type = .approve
        }

        return TransactionTagQuery(type: type, protocol: `protocol`, jettonAddress: jettonAddress, address: address)
    }
}

extension TonTransactionsAdapter: ITransactionsAdapter {
    var syncing: Bool {
        adapterState.syncing
    }

    var syncingObservable: Observable<Void> {
        adapterStateSubject.map { _ in () }
    }

    var lastBlockInfo: LastBlockInfo? {
        nil
    }

    var lastBlockUpdatedObservable: Observable<Void> {
        Observable.empty()
    }

    var explorerTitle: String {
        "tonscan.org"
    }

    var additionalTokenQueries: [TokenQuery] {
        []
    }

    func explorerUrl(transactionHash: String) -> String? {
        "https://tonscan.org/tx/\(transactionHash)"
    }

    func transactionsObservable(token: MarketKit.Token?, filter: TransactionTypeFilter, address: String?) -> Observable<[TransactionRecord]> {
        let address = address.flatMap { try? FriendlyAddress(string: $0) }?.address.toRaw()

        return tonKit.transactionsPublisher(tagQueries: [tagQuery(token: token, filter: filter, address: address)]).asObservable()
            .map { [weak self] in
                $0.compactMap { self?.transactionConverter.transactionRecord(fromTransaction: $0) }
            }
    }

    func transactionsSingle(from: TransactionRecord?, token: MarketKit.Token?, filter: TransactionTypeFilter, address: String?, limit: Int) -> Single<[TransactionRecord]> {
        let tagQueries = tagQuery(token: token, filter: filter, address: address)

        return Single.create { [weak self] observer in
            guard let self else {
                observer(.error(AppError.unknownError))
                return Disposables.create()
            }

            Task { [weak self] in
                let address = address.flatMap { try? FriendlyAddress(string: $0) }?.address.toRaw()

                let beforeLt = (from as? TonTransactionRecord).map(\.lt)

                let txs = (self?.tonKit
                    .transactions(tagQueries: [tagQueries], beforeLt: beforeLt, limit: limit)
                    .compactMap { self?.transactionConverter.transactionRecord(fromTransaction: $0) }) ?? []

                print("TonAdapter Send \(txs.count) transactions")
                observer(.success(txs))
            }

            return Disposables.create()
        }
    }

    func rawTransaction(hash _: String) -> String? {
        nil
    }

}
