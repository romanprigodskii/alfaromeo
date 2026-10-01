import SwiftUI

/// A monetary amount in Russian format (docs/DESIGN.md §6) with tabular figures, formatted by
/// ``MoneyFormat``: `1 119 200,50 ₽`, `+12 400 ₽`, `−1 240,50 ₽`, `0,1423 BTC`.
///
/// - `showsSign`: `+` for positives (negatives always carry `−`).
/// - `colorBySign`: credits in `success`, debits stay `textPrimary` (debits are normal life, not errors).
/// - `splitsKopecks`: hero style. Integer part at `size`, `,50 ₽` at ~0.65 × size in `textSecondary`.
///   Use it for the one main balance per screen (`AmountText(amount:, size: 40, splitsKopecks: true)`).
struct AmountText: View {
    var amount: Double
    var currency: String = "₽"
    var size: CGFloat = 28
    var showsSign: Bool = false
    var colorBySign: Bool = false
    var splitsKopecks: Bool = false

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sign: MoneyFormat.Sign { showsSign ? .always : .auto }

    private var formatted: String { MoneyFormat.amount(amount, currency: currency, sign: sign) }

    private var color: Color {
        guard colorBySign, amount > 0, formatted.contains(where: { $0.isNumber && $0 != "0" }) else {
            return theme.textPrimary
        }
        return theme.success
    }

    /// Small amounts in rows read better a touch lighter than display amounts.
    private var weight: Font.Weight { size < 20 ? .medium : .semibold }

    var body: some View {
        Group {
            if splitsKopecks && !MoneyFormat.isCryptoTicker(currency) {
                split
            } else {
                Text(formatted)
                    .font(BrandFont.amountFace(size, weight: weight))
                    .foregroundStyle(color)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(reduceMotion ? .identity : .numericText(value: amount))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(formatted)
    }

    private var split: some View {
        let parts = MoneyFormat.parts(amount, sign: sign)
        let tail = (parts.fraction ?? "") + MoneyFormat.nbsp + MoneyFormat.symbol(for: currency)
        let small = (size * 0.65).rounded()
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.integer)
                .font(BrandFont.amountFace(size, weight: .semibold))
                .foregroundStyle(color)
            Text(tail)
                .font(BrandFont.amountFace(small, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        AmountText(amount: 1_119_200.5, size: 40, splitsKopecks: true)
        AmountText(amount: 1234567.89)
        AmountText(amount: -1240.5, size: 17, showsSign: true, colorBySign: true)
        AmountText(amount: 12400, size: 17, showsSign: true, colorBySign: true)
        AmountText(amount: 0.1423, currency: "BTC", size: 22)
        AmountText(amount: 15890.5, currency: "USDT", size: 22)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
