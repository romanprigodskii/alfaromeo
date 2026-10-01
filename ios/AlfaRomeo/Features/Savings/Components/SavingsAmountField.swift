import SwiftUI

/// A preset value used by ``SavingsAmountField`` (сумма-пресет, напр. «Всё» / «100 000 ₽»).
struct AmountPreset: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: Double
}

/// Shared amount input for the deposit (₽) and stake (asset units) flows (§10.6). A large editable
/// amount with tabular figures + quick presets. Reused so both wizards type money the same way.
struct SavingsAmountField: View {
    @Binding var amount: Double
    var symbol: String
    var presets: [AmountPreset] = []
    var allowsDecimals: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                TextField("0", value: $amount, format: format)
                    .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.mono(40, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize()
                Text(symbol)
                    .font(BrandFont.heroKopecks)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            if !presets.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(presets) { preset in
                        Button { amount = preset.value } label: {
                            Text(preset.label)
                                .font(BrandFont.footnote.weight(.medium))
                                .monospacedDigit()
                                .lineLimit(1)
                                .foregroundStyle(isSelected(preset) ? theme.onAccent : theme.textPrimary)
                                .padding(.horizontal, Spacing.sm + 2)
                                .frame(height: 32)
                                .background(isSelected(preset) ? theme.accent : theme.fill,
                                            in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var format: FloatingPointFormatStyle<Double> {
        let ru = Locale(identifier: "ru_RU")
        return allowsDecimals
            ? .number.precision(.fractionLength(0...6)).locale(ru)
            : .number.precision(.fractionLength(0)).locale(ru)
    }

    private func isSelected(_ preset: AmountPreset) -> Bool { abs(amount - preset.value) < 0.000_000_1 }
}

#Preview {
    struct Demo: View {
        @State var amount: Double = 100_000
        var body: some View {
            SavingsAmountField(amount: $amount, symbol: "₽",
                               presets: [.init(label: MoneyFormat.fiat(50_000), value: 50_000),
                                         .init(label: MoneyFormat.fiat(100_000), value: 100_000),
                                         .init(label: MoneyFormat.fiat(500_000), value: 500_000)])
                .padding()
        }
    }
    return Demo().environment(\.theme, .default)
}
