import SwiftUI

/// 🆕 Привязка внешнего кошелька (§9.6): MetaMask / Trust / Ledger / TON. **Watch-only** — we never
/// connect to a chain; the user pastes an address (or mock-connects) and the wallet appears in the
/// unified portfolio read-only, valued at live ₽ prices. Linking a wallet adds it to the обзор.
struct ExternalWalletLinkView: View {
    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var prices = LivePriceService.shared
    @State private var selectedProvider: ExternalWalletProvider?
    @State private var addressText = ""
    @State private var labelText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                watchOnlyNote

                GroupedSection("Кошелёк") {
                    ForEach(ExternalWalletProvider.allCases) { provider in
                        ExternalWalletProviderTile(provider: provider) {
                            selectedProvider = provider
                            addressText = ""
                            labelText = provider.label
                        }
                    }
                }

                if !store.externalWallets.isEmpty {
                    GroupedSection("Привязанные") {
                        ForEach(store.externalWallets) { wallet in
                            ExternalWalletRow(wallet: wallet, valueRub: value(wallet)) {
                                withAnimation { store.unlinkExternalWallet(id: wallet.id) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Внешние кошельки")
        .navigationBarTitleDisplayMode(.inline)
        .bottomSheet(isPresented: Binding(get: { selectedProvider != nil }, set: { if !$0 { selectedProvider = nil } }),
                     detents: [.medium]) {
            if let provider = selectedProvider { linkSheet(provider) }
        }
    }

    private var watchOnlyNote: some View {
        Text("Только просмотр: подключения к блокчейну нет, баланс оценивается по адресу и live-ценам.")
            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkSheet(_ provider: ExternalWalletProvider) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                GlyphCircle(systemImage: provider.icon, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.label).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                    Text(provider.tagline).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
            }

            Text("Адрес кошелька").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            TextField(provider.addressPlaceholder, text: $addressText)
                .font(BrandFont.code(14))
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(Spacing.md)
                .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))

            SecondaryButton(title: "Вставить пример") {
                addressText = sampleAddress(provider)
            }

            PrimaryButton(title: "Привязать для просмотра") {
                let address = addressText.trimmingCharacters(in: .whitespaces).isEmpty ? sampleAddress(provider) : addressText
                store.linkExternalWallet(provider: provider, address: address, label: labelText)
                selectedProvider = nil
            }
        }
    }

    private func sampleAddress(_ provider: ExternalWalletProvider) -> String {
        switch provider {
        case .tonWallet: return "EQAbcdef1234567890ABCDEF1234567890abcdEFGh"
        default:         return "0x\(String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(38)))"
        }
    }

    private func value(_ wallet: ExternalWallet) -> Double {
        wallet.holdings.reduce(0) { $0 + prices.rubValue(asset: $1.asset, qty: $1.balance) }
    }
}

#Preview {
    NavigationStack {
        ExternalWalletLinkView()
            .environment(\.theme, .default)
    }
}
