import SwiftUI

/// The «одобрено до X» hero (§10.5 преодобренные суммы): the screen's one summary card. A hero
/// amount over a fill that shows the limit against the product ceiling, an optional personalised
/// rate, and, in the simulator, an animated signed Δ vs the base limit. Numerics animate, so toggling
/// a what-if lever visibly moves the number (honest, derived Δ). An optional trailing row opens the
/// explanation.
struct LimitGauge: View {
    var title: String
    var amount: Double
    var ceiling: Double
    var rateLabel: String? = nil
    var delta: Double = 0            // signed Δ vs base; 0 → hidden
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.theme) private var theme

    private var fill: Double { ceiling > 0 ? min(1, amount / ceiling) : 0 }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Spacer()
                    if delta != 0 {
                        Text(CreditFormat.signedRub(delta))
                            .font(BrandFont.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(delta > 0 ? theme.success : theme.textPrimary)
                            .contentTransition(.numericText())
                            .transition(.opacity)
                    }
                }

                AmountText(amount: amount, size: 40, splitsKopecks: true)
                    .contentTransition(.numericText())

                ProgressBar(value: fill, tint: theme.accent, height: 4)
                    .padding(.top, Spacing.xs)

                HStack(alignment: .firstTextBaseline) {
                    Text("Лимит продукта \(MoneyFormat.compact(ceiling))")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    Spacer()
                    if let rateLabel {
                        Text(rateLabel)
                            .font(BrandFont.footnote).monospacedDigit()
                            .foregroundStyle(theme.textPrimary)
                            .contentTransition(.numericText())
                    }
                }

                if let actionTitle, let action {
                    Hairline().padding(.top, Spacing.xs)
                    Button(action: action) {
                        HStack {
                            Text(actionTitle).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .animation(Motion.snappy, value: amount)
        .animation(Motion.snappy, value: delta)
    }
}
