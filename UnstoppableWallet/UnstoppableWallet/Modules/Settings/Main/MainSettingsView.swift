import Kingfisher
import SwiftUI
import ThemeKit

struct MainSettingsView: View {
    @StateObject var viewModel = MainSettingsViewModel()

    @State private var donatePresented = false
    @State private var manageWalletsPresented = false

    var body: some View {
        ScrollableThemeView {
            VStack(spacing: .margin32) {
                ListSection {
                    ClickableRow(action: {
                        donatePresented = true
                    }) {
                        Image("heart_fill_24").themeIcon(color: .themeJacob)
                        Text("settings.donate.title".localized).themeBody()
                        Image.disclosureIcon
                    }
                    .sheet(isPresented: $donatePresented) {
                        DonateTokenListView().ignoresSafeArea()
                    }
                }

                ListSection {
                    NavigationRow(destination: {
                        ManageAccountsView(mode: .manage)
                    }) {
                        Image("wallet_24").themeIcon()
                        Text("settings.manage_accounts".localized).themeBody()

                        if viewModel.manageWalletsAlert {
                            Image.warningIcon
                        }

                        Image.disclosureIcon
                    }

                    NavigationRow(destination: {
                        BlockchainSettingsModule.view()
                    }) {
                        Image("blocks_24").themeIcon()
                        Text("settings.blockchain_settings".localized).themeBody()
                        Image.disclosureIcon
                    }

                    NavigationRow(destination: {
                        BackupManagerView()
                    }) {
                        Image("icloud_24").themeIcon()
                        Text("settings.backup_manager".localized).themeBody()
                        Image.disclosureIcon
                    }
                }

                ListSection {
                    NavigationRow(destination: {
                        SecuritySettingsModule.view()
                    }) {
                        Image("shield_24").themeIcon()
                        Text("settings.security".localized).themeBody()

                        if viewModel.securityAlert {
                            Image.warningIcon
                        }

                        Image.disclosureIcon
                    }

                    NavigationRow(destination: {
                        AppearanceView()
                    }) {
                        Image("brush_24").themeIcon()
                        Text("appearance.title".localized).themeBody()
                        Image.disclosureIcon
                    }

                    NavigationRow(destination: {
                        BaseCurrencySettingsModule.view()
                    }) {
                        Image("usd_24").themeIcon()
                        HStack(spacing: .margin8) {
                            Text("settings.base_currency".localized).textBody()
                            Spacer()
                            Text(viewModel.baseCurrencyCode).textSubhead1()
                        }
                        Image.disclosureIcon
                    }

                    NavigationRow(destination: {
                        LanguageSettingsModule.view()
                    }) {
                        Image("globe_24").themeIcon()
                        HStack(spacing: .margin8) {
                            Text("settings.language".localized).textBody()

                            if let language = LanguageManager.shared.currentLanguageDisplayName {
                                Spacer()
                                Text(language).textSubhead1()
                            }
                        }
                        Image.disclosureIcon
                    }
                }
            }
            .padding(EdgeInsets(top: .margin12, leading: .margin16, bottom: .margin32, trailing: .margin16))
        }
        .navigationTitle("settings.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
