import Combine
import Foundation
import HdWalletKit
import HsToolKit
import MarketKit
import RxRelay
import RxSwift
import TonKit
import TonSwift
import TweetNacl

class TonKitManager {
    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()
    private let testNetManager: TestNetManager

    private weak var _tonKit: TonKit.Kit?

    private let tonKitCreatedRelay = PublishRelay<Void>()
    private var currentAccount: Account?
    private var kitStarted = false

    private let queue = DispatchQueue(label: "\(AppConfig.label).ton-kit-manager", qos: .userInitiated)

    init(testNetManager: TestNetManager) {
        self.testNetManager = testNetManager
    }

    private func initKit(type: TonKit.Kit.WalletType, walletId: String, network: Network) throws -> TonKit.Kit {
        let logger = Logger(minLogLevel: .error)
        let tonKit = try Kit.instance(
            type: type,
            network: network,
            walletId: walletId,
            apiKey: nil,
            logger: logger
        )

        return tonKit
    }

    private func _tonKit(account: Account) throws -> TonKit.Kit {
        if let _tonKit, let currentAccount, currentAccount == account {
            return _tonKit
        }

        let network: Network = testNetManager.testNetEnabled ? .testNet : .mainNet
        let tonKit: TonKit.Kit

        switch account.type {
        case .mnemonic:
            guard let seed = account.type.mnemonicSeed else {
                throw KitWrapperError.mnemonicNoSeed
            }

            let hdWallet = HDWallet(seed: seed, coinType: 607, xPrivKey: 0, curve: .ed25519)
            let privateKey = try hdWallet.privateKey(account: 0)
            let privateRaw = Data(privateKey.raw.bytes)
            let pair = try TweetNacl.NaclSign.KeyPair.keyPair(fromSeed: privateRaw)
            let keyPair = KeyPair(publicKey: .init(data: pair.publicKey),
                                  privateKey: .init(data: pair.secretKey))

            tonKit = try initKit(
                type: .full(keyPair),
                walletId: account.id,
                network: network
            )
        case let .tonAddress(value):
            let watchAddress = try FriendlyAddress(string: value)
 
            tonKit = try initKit(
                type: .watch(watchAddress.address),
                walletId: account.id,
                network: network
            )
        default:
            throw AdapterError.unsupportedAccount
        }

        print("TonKitManager: Create and Start Kit!")
        tonKit.start()
        kitStarted = true

        _tonKit = tonKit
        currentAccount = account

        tonKitCreatedRelay.accept(())

        return tonKit
    }

    func willEnterForeground() {
        if !kitStarted, let _tonKit {
            print("TonKitManager: Start Kit!")
            _tonKit.start()
            kitStarted.toggle()
        }
    }

    func didEnterBackground() {
        if kitStarted, let _tonKit {
            print("TonKitManager: Stop Kit!")
            _tonKit.stop()
            kitStarted.toggle()
        }
    }
}

extension TonKitManager {
    var tonKitCreatedObservable: Observable<Void> {
        tonKitCreatedRelay.asObservable()
    }

    var tonKit: TonKit.Kit? {
        queue.sync {
            _tonKit
        }
    }

    func tonKit(account: Account) throws -> TonKit.Kit {
        try queue.sync {
            try _tonKit(account: account)
        }
    }
}

extension TonKitManager {
    enum KitWrapperError: Error {
        case mnemonicNoSeed
    }
}
