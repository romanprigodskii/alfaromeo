import SwiftUI

/// One analytics hint (§10.7 «AI-прогноз / аномалии») as a plain grouped row: monochrome glyph, a
/// short title and one factual sentence. No gradients or badges (docs/DESIGN.md §7); the «демо»
/// disclosure lives once in the section footer.
struct AIInsightCard: View {
    let insight: AIInsight

    @Environment(\.theme) private var theme

    private var icon: String {
        switch insight.kind {
        case .forecast: return "chart.line.uptrend.xyaxis"
        case .anomaly:  return "exclamationmark.triangle"
        case .tip:      return "lightbulb"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: icon, size: ListRow.glyphSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                Text(insight.message)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}

#Preview {
    GroupedSection("Подсказки", footer: "Демо, рассчитано по операциям месяца.") {
        AIInsightCard(insight: AIInsight(kind: .forecast, title: "Прогноз к концу месяца",
            message: "При текущем темпе расходы составят около 48 200 ₽."))
        AIInsightCard(insight: AIInsight(kind: .anomaly, title: "Крупнейшая категория",
            message: "«Маркетплейсы»: 7 800 ₽, 32 % расходов."))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
