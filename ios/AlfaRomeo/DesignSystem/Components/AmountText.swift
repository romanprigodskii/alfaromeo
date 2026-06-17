import SwiftUI

/// Monetary amount in the basic ``BrandFont/amountFace`` with tabular (`.monospacedDigit()`) figures so
/// columns still align. Optional sign + coloring. (Font swap point: ``BrandFont/amountFace``.)
struct AmountText: View {
    var amount: Double
    var currency: String = "₽"
    var size: CGFloat = 28
    var showsSign: Bool = false
    var colorBySign: Bool = false

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}" // non-breaking space — a visible group gap in the proportional amount font (U+2009 thin space collapses there)
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    private var formatted: String {
        let magnitude = Self.formatter.string(from: NSNumber(value: abs(amount))) ?? "\(abs(amount))"
        let sign = amount < 0 ? "\u{2212}" : (showsSign ? "+" : "") // U+2212 minus
        return "\(sign)\(magnitude)\u{00A0}\(currency)" // NBSP before currency so the amount never wraps before ₽
    }

    private var color: Color {
        guard colorBySign else { return theme.textPrimary }
        if amount > 0 { return theme.success }
        if amount < 0 { return theme.danger }
        return theme.textPrimary
    }

    var body: some View {
        Text(formatted)
            .font(BrandFont.amountFace(size, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .accessibilityLabel(formatted)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        AmountText(amount: 1234567.89)
        AmountText(amount: -2400, size: 20, showsSign: true, colorBySign: true)
        AmountText(amount: 980, size: 20, showsSign: true, colorBySign: true)
        AmountText(amount: 15890.5, currency: "USDT", size: 22)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
