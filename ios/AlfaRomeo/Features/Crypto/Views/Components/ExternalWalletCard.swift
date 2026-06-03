import SwiftUI

/// Provider tile for the link screen (§9.6 🆕): MetaMask / Trust / Ledger / TON. Tap to start a
/// watch-only link.
struct ExternalWalletProviderTile: View {
    let provider: ExternalWalletProvider
    var onTap: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ZStack {
                    Circle().fill(theme.cryptoGradient).frame(width: 40, height: 40)
                    Image(systemName: provider.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(provider.label)
                    .font(BrandFont.bodyM.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(provider.tagline)
                    .font(BrandFont.micro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// A linked watch-only wallet summary (§9.6): provider, masked address, ₽ value, read-only chip.
/// When `onUnlink` is supplied, a trailing menu offers «Отвязать» — removing the watch-only link so the
/// unified portfolio recomputes (``CryptoStore/unlinkExternalWallet(id:)``).
struct ExternalWalletRow: View {
    let wallet: ExternalWallet
    let valueRub: Double
    /// Display currency for the ₽ value (§9.6 ₽/$ toggle).
    var denomination: PortfolioDenomination = .rub
    var usdRub: Double = 1
    var onUnlink: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @State private var confirmUnlink = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(theme.cryptoGradient).frame(width: 40, height: 40)
                Image(systemName: wallet.provider.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(wallet.label).font(BrandFont.bodyM.weight(.semibold)).foregroundStyle(theme.textPrimary)
                    Text("watch-only")
                        .font(BrandFont.micro.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(theme.elevated, in: Capsule())
                        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
                }
                Text(wallet.shortAddress).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            Text(CryptoFormat.money(valueRub, denom: denomination, usdRub: usdRub, fraction: 0))
                .font(BrandFont.amountS).foregroundStyle(theme.textPrimary).monospacedDigit()

            if onUnlink != nil {
                Menu {
                    Button(role: .destructive) { confirmUnlink = true } label: {
                        Label("Отвязать кошелёк", systemImage: "minus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Действия с кошельком")
            }
        }
        .padding(.vertical, Spacing.sm)
        .confirmationDialog("Отвязать «\(wallet.label)»?", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("Отвязать", role: .destructive) { onUnlink?() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Кошелёк watch-only — средства не двигаются. Он исчезнет из портфеля; привязать снова можно в любой момент.")
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.md) {
            ExternalWalletProviderTile(provider: .metaMask)
            ExternalWalletProviderTile(provider: .ledger)
        }
        ExternalWalletRow(wallet: MockCryptoData.seededExternalWallets[0], valueRub: 612_400)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
