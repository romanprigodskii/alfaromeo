import SwiftUI

/// Daily revenue at the top of the acquiring hub, hero style (no card): total, count, the crypto
/// conversion note, and the live-rate dot. Tapping it opens the revenue report.
struct RevenueHeroCard: View {
    @Environment(\.theme) private var theme

    let summary: RevenueSummary
    let isLive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                header
                AmountText(amount: summary.total, size: 40, splitsKopecks: true)
                Text(subline)
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Открыть отчёт")
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Text("Выручка за сутки")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
            Spacer(minLength: Spacing.sm)
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

    private var subline: String {
        var line = "\(summary.count) поступлений"
        if summary.cryptoConvertedRub > 0 {
            line += " · из крипты \(MoneyFormat.compact(summary.cryptoConvertedRub))"
        }
        return line
    }
}

#Preview {
    RevenueHeroCard_PreviewHost()
}

private struct RevenueHeroCard_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            RevenueHeroCard(
                summary: RevenueSummary(
                    total: 1_284_500,
                    count: 47,
                    cryptoConvertedRub: 312_000,
                    byMethod: []
                ),
                isLive: true,
                action: {}
            )
            RevenueHeroCard(
                summary: .empty,
                isLive: false,
                action: {}
            )
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}
