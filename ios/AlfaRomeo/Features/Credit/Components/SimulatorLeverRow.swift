import SwiftUI

/// A what-if lever in the pre-qual simulator (§10.5 «если закрыть карту X, лимит +Y»), one row of
/// the grouped section. Shows the exact derived Δ to the limit from toggling it; tapping applies it
/// and the hero ``LimitGauge`` animates to the new amount.
struct SimulatorLeverRow: View {
    let lever: SimulatorLever
    let delta: Double            // exact Δ to the approved limit (derived, signed)
    let isOn: Bool
    var onToggle: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: lever.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lever.title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(lever.subtitle).font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                    // Applied levers are already folded into the limit; the row's tap REMOVES them, so
                    // a green «+Δ» would be misleading. Show «учтено» when on, the potential gain when off.
                    Group {
                        if isOn {
                            Text("Учтено в лимите").foregroundStyle(theme.textSecondary)
                        } else if delta > 0 {
                            Text("Лимит \(CreditFormat.signedRub(delta))").foregroundStyle(theme.success)
                        } else {
                            Text("Лимит не изменится").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .font(BrandFont.subheadline).monospacedDigit()
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? theme.accent : theme.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityLabel("\(lever.title), \(isOn ? "включено" : "выключено"), эффект \(CreditFormat.signedRub(delta))")
    }
}
