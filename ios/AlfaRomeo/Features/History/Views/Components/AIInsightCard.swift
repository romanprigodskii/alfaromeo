import SwiftUI

/// AI-style insight surface (§10.7 «AI-прогноз / аномалии»). Uses the cold crypto/AI gradient accent
/// to mark it as an AI surface (§13.1) and carries a «демо» tag — real model-backed insights ship in
/// Фаза 3 (§10.9).
struct AIInsightCard: View {
    let insight: AIInsight

    @Environment(\.theme) private var theme

    // Cold crypto/AI stops via the semantic theme tokens (§13.1), not raw BrandColors.
    private var cryptoBackdrop: Color { (theme.accentCrypto.first ?? theme.accent).opacity(0.14) }
    private var cryptoBadge: Color { theme.accentCrypto.last ?? theme.accent }

    private var icon: String {
        switch insight.kind {
        case .forecast: return "chart.line.uptrend.xyaxis"
        case .anomaly:  return "exclamationmark.triangle.fill"
        case .tip:      return "lightbulb.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.cryptoGradient)
                .frame(width: 36, height: 36)
                .background(
                    cryptoBackdrop,
                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(insight.title)
                        .font(BrandFont.headline)
                        .foregroundStyle(theme.textPrimary)
                    Badge(kind: .text("AI · демо"), tint: cryptoBadge)
                }
                Text(insight.message)
                    .font(BrandFont.callout)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.cryptoGradient.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        AIInsightCard(insight: AIInsight(kind: .forecast, title: "Прогноз к концу месяца",
            message: "При текущем темпе расходы составят ≈ 48 200 ₽."))
        AIInsightCard(insight: AIInsight(kind: .anomaly, title: "Крупнейшая категория",
            message: "«Маркетплейсы» — 7 800 ₽ (32% расходов)."))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
