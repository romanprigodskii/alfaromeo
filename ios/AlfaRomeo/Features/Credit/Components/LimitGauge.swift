import SwiftUI

/// The «одобрено до X» hero (§10.5 преодобренные суммы). A big monospaced amount over a fill that
/// shows the limit against the product ceiling, an optional personalised rate, and — in the
/// simulator — an animated signed Δ vs the base limit. Numerics animate, so toggling a what-if lever
/// visibly moves the number (honest, derived Δ).
struct LimitGauge: View {
    var title: String
    var amount: Double
    var ceiling: Double
    var rateLabel: String? = nil
    var delta: Double = 0            // signed Δ vs base; 0 → hidden

    @Environment(\.theme) private var theme

    private var fill: Double { ceiling > 0 ? min(1, amount / ceiling) : 0 }

    var body: some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text(title).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    if delta != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text(CreditFormat.signedRub(delta)).font(BrandFont.caption.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(delta > 0 ? theme.success : theme.danger)
                        .transition(.opacity)
                    }
                }

                AmountText(amount: amount, size: 34)
                    .contentTransition(.numericText())

                ProgressBar(value: fill, tint: theme.accent, height: 6)

                HStack {
                    Text("Лимит продукта \(CreditFormat.rub(ceiling))")
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    Spacer()
                    if let rateLabel {
                        Text(rateLabel).font(BrandFont.micro.weight(.semibold)).foregroundStyle(theme.textPrimary)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .animation(Motion.snappy, value: amount)
        .animation(Motion.snappy, value: delta)
    }
}
