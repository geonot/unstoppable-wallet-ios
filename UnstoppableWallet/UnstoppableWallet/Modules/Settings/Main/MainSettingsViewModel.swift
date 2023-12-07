import Combine
import MarketKit
import RxSwift
import ThemeKit

class MainSettingsViewModel: ObservableObject {
    private let disposeBag = DisposeBag()
    private var cancellables = Set<AnyCancellable>()

    private let backupManager = App.shared.backupManager
    private let cloudBackupManager = App.shared.cloudBackupManager
    private let accountRestoreWarningManager = App.shared.accountRestoreWarningManager
    private let accountManager = App.shared.accountManager
    private let contactManager = App.shared.contactManager
    private let passcodeManager = App.shared.passcodeManager
    private let termsManager = App.shared.termsManager
    private let systemInfoManager = App.shared.systemInfoManager
    private let currencyManager = App.shared.currencyManager
    private let walletConnectSessionManager = App.shared.walletConnectSessionManager
    private let subscriptionManager = App.shared.subscriptionManager
    private let rateAppManager = App.shared.rateAppManager

    @Published var manageWalletsAlert: Bool = false
    @Published var securityAlert: Bool = false
    @Published var baseCurrencyCode: String = ""

    init() {
        syncManageWalletsAlert()
        syncSecurityAlert()
        syncBaseCurrencyCode()

        subscribe(disposeBag, backupManager.allBackedUpObservable) { [weak self] _ in self?.syncManageWalletsAlert() }
        subscribe(disposeBag, accountRestoreWarningManager.hasNonStandardObservable) { [weak self] _ in self?.syncManageWalletsAlert() }

        passcodeManager.$isPasscodeSet.sink { [weak self] _ in self?.syncSecurityAlert() }.store(in: &cancellables)
        currencyManager.$baseCurrency.sink { [weak self] _ in self?.syncBaseCurrencyCode() }.store(in: &cancellables)
    }

    private func syncManageWalletsAlert() {
        manageWalletsAlert = !backupManager.allBackedUp || accountRestoreWarningManager.hasNonStandard
    }

    private func syncSecurityAlert() {
        securityAlert = !passcodeManager.isPasscodeSet
    }

    private func syncBaseCurrencyCode() {
        baseCurrencyCode = currencyManager.baseCurrency.code
    }
}
