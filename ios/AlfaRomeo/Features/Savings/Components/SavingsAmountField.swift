import SwiftUI

/// A preset value used by ``SavingsAmountField`` (сумма-пресет, напр. «Всё» / «100 000»).
struct AmountPreset: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: Double
}

/// Shared amount input for the deposit (₽) and stake (asset units) flows (§10.6). A big monospaced
/// editable amount + quick presets. Reused so both wizards type money the same way.
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
                    .font(BrandFont.mono(22, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            if !presets.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(presets) { preset in
                        Button { amount = preset.value } label: {
                            Text(preset.label)
                                .font(BrandFont.caption)
                                .foregroundStyle(isSelected(preset) ? theme.onAccent : theme.textPrimary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.xs)
                                .background(isSelected(preset) ? theme.accent : theme.elevated, in: Capsule())
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private var format: FloatingPointFormatStyle<Double> {
        allowsDecimals ? .number.precision(.fractionLength(0...6)) : .number.precision(.fractionLength(0))
    }

    private func isSelected(_ preset: AmountPreset) -> Bool { abs(amount - preset.value) < 0.000_000_1 }
}

/// A compact info/option chip used across the hub (срок, капитализация, уровень риска…).
struct SavingsChip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(BrandFont.micro)
        }
        .foregroundStyle(tint ?? theme.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background((tint ?? theme.textSecondary).opacity(0.12), in: Capsule())
    }
}

#Preview {
    struct Demo: View {
        @State var amount: Double = 100_000
        var body: some View {
            VStack(spacing: Spacing.lg) {
                SavingsAmountField(amount: $amount, symbol: "₽",
                                   presets: [.init(label: "50 000", value: 50_000),
                                             .init(label: "100 000", value: 100_000),
                                             .init(label: "500 000", value: 500_000)])
                HStack { SavingsChip(text: "капитализация", systemImage: "arrow.triangle.2.circlepath")
                         SavingsChip(text: "Низкий риск", tint: .green) }
            }
            .padding()
        }
    }
    return Demo().environment(\.theme, .default)
}
