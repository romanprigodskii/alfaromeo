import SwiftUI

/// The total ₽ balance across every business account: ₽ settlement + multicurrency + crypto treasury
/// (§8.2). Shared by the Счета header (read-only) and the Дашборд balance block (tappable → Счета tab).
/// Hero style per DESIGN §3/§6: no card, 40pt integer part with smaller kopecks. The «live-курс /
/// оффлайн-курс» dot reflects ``LivePriceService``, so a stale price book is never presented as live.
struct AccountBalanceHero: View {
    /// One labelled breakdown figure under the hero amount («Расчётный 2,1 млн ₽»).
    struct Stat: Hashable {
        let label: String
        let value: String
    }

    let totalRub: Double
    let isLive: Bool
    var stats: [Stat] = []
    /// Data lines under the figures (account count, which rate the valuation uses).
    var footnote: String? = nil
    /// When set, the block becomes a button (used on the dashboard to open Счета).
    var action: (() -> Void)? = nil

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Открыть счета")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Баланс по всем счетам")
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer(minLength: Spacing.sm)
                livePill
            }

            AmountText(amount: totalRub, size: 40, splitsKopecks: true)
                .animation(reduceMotion ? nil : Motion.snappy, value: totalRub)

            if !stats.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.md) { statViews }
                    VStack(alignment: .leading, spacing: Spacing.xxs) { statViews }
                }
                .padding(.top, Spacing.xxs)
            }

            if let footnote {
                Text(footnote)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var statViews: some View {
        ForEach(stats, id: \.self) { stat in
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs + 2) {
                Text(stat.label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Text(stat.value).font(BrandFont.body(15, weight: .medium)).monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
            }
            .fixedSize()
        }
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text(isLive ? "live-курс" : "оффлайн-курс")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
        }
    }
}
