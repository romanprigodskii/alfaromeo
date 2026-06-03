import SwiftUI

/// Horizontal progress for goals / limits / data (GB). Value clamped 0...1, animated fill.
/// Optionally uses the crypto/AI cold gradient.
struct ProgressBar: View {
    var value: Double
    var tint: Color? = nil
    var useCryptoGradient: Bool = false
    var height: CGFloat = 8

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(value, 0), 1) }

    private var fill: AnyShapeStyle {
        useCryptoGradient
            ? AnyShapeStyle(theme.cryptoGradient)
            : AnyShapeStyle(tint ?? theme.accent)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border)
                Capsule()
                    .fill(fill)
                    .frame(width: max(height, geo.size.width * clamped))
            }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : Motion.progress, value: clamped)
        .accessibilityValue("\(Int(clamped * 100))%")
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ProgressBar(value: 0.62)
        ProgressBar(value: 0.3, useCryptoGradient: true)
        ProgressBar(value: 0.85, tint: Theme.default.success)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
