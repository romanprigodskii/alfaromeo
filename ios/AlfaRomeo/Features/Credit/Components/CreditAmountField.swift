import SwiftUI

/// A preset value for ``CreditAmountField`` (напр. «25%» / «Максимум»).
struct CreditAmountPreset: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: Double
}

/// Big monospaced ₽ amount input + a drag-to-choose slider + quick presets for the application wizard
/// (§10.5 «сумма»). You can type a precise sum OR drag the slider up to the requestable ceiling.
/// Module-local by the repo's per-feature convention (Savings has its own ``SavingsAmountField``).
struct CreditAmountField: View {
    @Binding var amount: Double
    var presets: [CreditAmountPreset] = []
    /// When set, shows a slider (min…max) so the amount is choosable by dragging. Stepped to `step`.
    var range: ClosedRange<Double>? = nil
    var step: Double = 10_000

    @Environment(\.theme) private var theme

    /// Slider value clamped into range; writing back snaps to `step`.
    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(amount, range?.lowerBound ?? 0), range?.upperBound ?? amount) },
            set: { amount = ((($0) / step).rounded() * step) }
        )
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                TextField("0", value: $amount,
                          format: .number.precision(.fractionLength(0)).locale(Locale(identifier: "ru_RU")))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.mono(40, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize()
                Text("₽")
                    .font(BrandFont.mono(22, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            if let range {
                VStack(spacing: 2) {
                    Slider(value: sliderBinding, in: range, step: step)
                        .tint(theme.accent)
                    HStack {
                        Text(CreditFormat.rub(range.lowerBound)).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text("до \(CreditFormat.rub(range.upperBound))").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                }
            }

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

    private func isSelected(_ preset: CreditAmountPreset) -> Bool { abs(amount - preset.value) < 0.5 }
}

/// A compact info chip used across the credit hub (срок, грейс, уровень…).
struct CreditChip: View {
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
