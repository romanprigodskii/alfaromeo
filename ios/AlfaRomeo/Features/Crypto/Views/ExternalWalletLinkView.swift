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

    private let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                watchOnlyNote

                Text("Выберите кошелёк").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(ExternalWalletProvider.allCases) { provider in
                        ExternalWalletProviderTile(provider: provider) {
                            selectedProvider = provider
                            addressText = ""
                            labelText = provider.label
                        }
                    }
                }

                if !store.externalWallets.isEmpty {
                    Text("Привязанные").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    SurfaceCard(padding: Spacing.sm) {
                        VStack(spacing: 0) {
                            ForEach(Array(store.externalWallets.enumerated()), id: \.element.id) { index, wallet in
                                if index > 0 { Divider().overlay(theme.border) }
                                ExternalWalletRow(wallet: wallet, valueRub: value(wallet)) {
                                    withAnimation { store.unlinkExternalWallet(id: wallet.id) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
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
        HStack(spacing: Spacing.sm) {
            Image(systemName: "eye.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accentCrypto.first ?? theme.accent)
            Text("Только просмотр (watch-only). Подключения к блокчейну не происходит — баланс оценивается по адресу и live-ценам.")
                .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func linkSheet(_ provider: ExternalWalletProvider) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(theme.cryptoGradient).frame(width: 40, height: 40)
                    Image(systemName: provider.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.label).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    Text(provider.tagline).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }

            Text("Адрес кошелька").font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            TextField(provider.addressPlaceholder, text: $addressText)
                .font(BrandFont.mono(14))
                .foregroundStyle(theme.textPrimary)
                .padding(Spacing.md)
                .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))

            HStack(spacing: Spacing.sm) {
                SecondaryButton(title: "Вставить пример", icon: "doc.on.clipboard") {
                    addressText = sampleAddress(provider)
                }
            }

            PrimaryButton(title: "Привязать (watch-only)", icon: "link") {
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
