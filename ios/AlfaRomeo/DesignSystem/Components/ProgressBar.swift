import SwiftUI

/// Flat horizontal progress for goals / limits / data (docs/DESIGN.md §5): `fill` track, solid bar.
/// Value is clamped to 0...1. `useCryptoGradient` is kept for source compatibility and draws the same
/// solid bar (no decorative gradients).
struct ProgressBar: View {
    var value: Double
    var tint: Color? = nil
    var useCryptoGradient: Bool = false
    var height: CGFloat = 6

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.fill)
                Capsule()
                    .fill(tint ?? theme.accent)
                    .frame(width: clamped > 0 ? max(height, geo.size.width * clamped) : 0)
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : Motion.progress, value: clamped)
        .accessibilityValue(MoneyFormat.percent(fraction: clamped, maxFractionDigits: 0))
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ProgressBar(value: 0.62)
        ProgressBar(value: 0.3, tint: Theme.default.textPrimary)
        ProgressBar(value: 0.85, tint: Theme.default.success)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
