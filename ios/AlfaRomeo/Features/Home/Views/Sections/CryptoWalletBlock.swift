import SwiftUI

/// Crypto wallet block (§9.1): the live ₽ valuation of the portfolio (§11.4) with per-asset chips.
/// Tapping opens the crypto hub stub (``HomeRoute.crypto``, §9.6).
struct CryptoWalletBlock: View {
    let dashboard: HomeDashboard
    let live: [String: Double]
    var onTap: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var valueRub: Double { dashboard.cryptoValueRub(live: live) }

    var body: some View {
        DashboardSection(title: "Крипто-кошелёк", actionTitle: "Открыть", action: onTap) {
            Button(action: onTap) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(theme.cryptoGradient)
                            Text("Оценка портфеля").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text("LIVE")
                                .font(BrandFont.micro)
                                .foregroundStyle(theme.accentCrypto.last ?? theme.accent)
                        }
                        AmountText(amount: valueRub, size: 26)
                            .animation(reduceMotion ? nil : Motion.snappy, value: valueRub)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(dashboard.wallets) { wallet in
                                    assetChip(wallet)
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func assetChip(_ wallet: CryptoWallet) -> some View {
        HStack(spacing: 6) {
            Text(wallet.asset).font(BrandFont.mono(12, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text(trimmed(wallet.balance)).font(BrandFont.mono(12)).foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm).padding(.vertical, 6)
        .background(theme.elevated, in: Capsule())
        .overlay(Capsule().stroke(theme.border, lineWidth: 1))
    }

    private func trimmed(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f", value) : String(format: "%.4f", value)
    }
}
