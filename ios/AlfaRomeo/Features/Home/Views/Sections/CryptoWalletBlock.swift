import SwiftUI

/// Crypto wallet block (§9.1): the live ₽ valuation of the portfolio (§11.4), then one row per asset
/// with its real coin logo, quantity and ₽ value. Every row opens the crypto hub (``HomeRoute.crypto``).
struct CryptoWalletBlock: View {
    let dashboard: HomeDashboard
    let live: [String: Double]
    var onTap: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var valueRub: Double { dashboard.cryptoValueRub(live: live) }

    var body: some View {
        GroupedSection("Крипто-кошелёк") {
            Button(action: onTap) { summary }
                .buttonStyle(.row)
            ForEach(dashboard.wallets) { wallet in
                Button(action: onTap) { row(wallet) }
                    .buttonStyle(.row)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Оценка портфеля")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                AmountText(amount: valueRub, size: 22)
                    .animation(reduceMotion ? nil : Motion.snappy, value: valueRub)
            }
            Spacer(minLength: Spacing.sm)
            if !live.isEmpty { liveMark }
            chevron
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func row(_ wallet: CryptoWallet) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            CoinLogo(symbol: wallet.asset, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(wallet.asset)
                    .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(MoneyFormat.crypto(wallet.balance, symbol: wallet.asset))
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            AmountText(amount: wallet.balance * dashboard.price(for: wallet.asset, live: live), size: 17)
                .layoutPriority(1)
            chevron
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }

    /// Shown once a live tick has arrived, so the label never claims a stream that is not there.
    private var liveMark: some View {
        HStack(spacing: Spacing.xxs + 2) {
            Circle().fill(theme.success).frame(width: 6, height: 6)
            Text("live").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
    }
}
