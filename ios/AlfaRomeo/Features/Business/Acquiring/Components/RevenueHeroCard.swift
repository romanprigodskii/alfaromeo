import SwiftUI

/// Component #2 — hero card at the top of the acquiring hub.
/// Shows daily revenue total, count, optional crypto-conversion note, and a
/// live-rate indicator. Tapping the whole card opens the revenue report.
struct RevenueHeroCard: View {
    @Environment(\.theme) private var theme

    let summary: RevenueSummary
    let isLive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SurfaceCard(elevated: true) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    amountBlock
                    Divider().overlay(theme.border)
                    footer
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text("ВЫРУЧКА · ЗА СУТКИ")
                .font(BrandFont.micro.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            livePill
        }
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(isLive ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text(isLive ? "live-курс" : "оффлайн-курс")
                .font(BrandFont.micro.weight(.medium))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            (isLive ? theme.success : theme.warning).opacity(0.12),
            in: Capsule(style: .continuous)
        )
    }

    // MARK: - Amount

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AmountText(amount: summary.total, size: 34)
            Text(subline)
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var subline: String {
        var line = "\(summary.count) поступлений"
        if summary.cryptoConvertedRub > 0 {
            line += " · крипто-конвертация \(CryptoFormat.compactRub(summary.cryptoConvertedRub))"
        }
        return line
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.xxs) {
            Text("Открыть отчёт")
                .font(BrandFont.caption.weight(.medium))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(theme.accent)
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
