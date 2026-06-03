import SwiftUI

/// Component #10 — a large themed numeric input used by create-link and accept-payment.
/// No formatting-on-type; the model parses the raw text via `CryptoFormat.parse`.
struct AcquiringAmountField: View {
    @Environment(\.theme) private var theme

    let title: String
    var placeholder: String = "0"
    @Binding var text: String
    var currency: String = "₽"

    var body: some View {
        SurfaceCard(padding: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    TextField(placeholder, text: $text)
                        .keyboardType(.decimalPad)
                        .font(BrandFont.mono(34, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()

                    Text(currency)
                        .font(BrandFont.mono(22))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }
}

private struct AcquiringAmountField_PreviewHost: View {
    @State private var amount = "12500"
    @State private var empty = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            AcquiringAmountField(title: "Сумма к оплате", text: $amount)
            AcquiringAmountField(title: "Сумма", placeholder: "0", text: $empty, currency: "USDT")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}

#Preview {
    AcquiringAmountField_PreviewHost()
}
