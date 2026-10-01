import SwiftUI

/// Large amount entry with tabular figures. Autofocuses a decimal keypad, shows the
/// currency symbol, an optional secondary line (₽-эквивалент / «доступно»), and quick-amount chips.
struct AmountEntry: View {
    @Binding var text: String
    var symbol: String
    var secondary: String? = nil
    var secondaryIsWarning: Bool = false
    var quickAmounts: [Double] = []
    var onQuick: (Double) -> Void = { _ in }

    @Environment(\.theme) private var theme
    @FocusState private var focused: Bool

    // Saturated danger hue fails AA as text on a pale light surface — use the DS ink variant there
    // (mirrors StatusPill). No-op in the app's dark-only ship; correct if light mode is ever enabled.
    private var dangerInk: Color { theme.isDark ? theme.danger : BrandColors.dangerInkLight }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .font(BrandFont.mono(40, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)   // scale digits at large Dynamic Type sizes, never clip
                    .multilineTextAlignment(.center)
                Text(MoneyFormat.symbol(for: symbol))
                    .font(BrandFont.mono(26, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)

            if let secondary {
                Text(secondary)
                    .font(BrandFont.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(secondaryIsWarning ? dangerInk : theme.textSecondary)
                    .contentTransition(.numericText())
            }

            if !quickAmounts.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(quickAmounts, id: \.self) { value in
                        Button { onQuick(value) } label: {
                            Text(MoneyFormat.number(value, sign: .always))
                                .font(BrandFont.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(theme.textPrimary)
                                .padding(.horizontal, Spacing.md - 4)
                                .frame(minHeight: 36)
                                .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear { focused = true }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

}

#Preview {
    AmountEntry(text: .constant("5000"), symbol: "₽",
                secondary: "Доступно: 184\u{00A0}200\u{00A0}₽", quickAmounts: [1000, 5000, 10000])
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
