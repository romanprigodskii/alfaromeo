import SwiftUI

/// One explainable decision factor (§10.5 «факторы решения») as a row of the grouped section:
/// label, value, status pill and a contribution bar, tappable to reveal the plain-language
/// «почему так» and a «что улучшить» hint. The bar fill is the factor's support for the limit.
struct FactorRow: View {
    let factor: DecisionFactor
    @State private var expanded = false

    @Environment(\.theme) private var theme

    private var pillStatus: StatusPill.Status {
        switch factor.status {
        case .good: return .success
        case .ok:   return .warning
        case .weak: return .declined
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                withAnimation(Motion.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: ListRow.glyphSpacing) {
                    GlyphCircle(systemImage: factor.kind.systemImage)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.kind.title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Text(factor.valueLabel).font(BrandFont.subheadline).monospacedDigit()
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: Spacing.sm)
                    StatusPill(status: pillStatus, text: factor.status.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityHint(expanded ? "Свернуть" : "Подробнее")

            ProgressBar(value: factor.contribution, tint: theme.textPrimary, height: 4)
                .padding(.leading, ListRow.glyphSize + ListRow.glyphSpacing)

            if expanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(factor.explanation)
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let improvement = factor.improvement {
                        Text("Что улучшить: \(improvement)")
                            .font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, ListRow.glyphSize + ListRow.glyphSpacing)
                .transition(.opacity)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}
