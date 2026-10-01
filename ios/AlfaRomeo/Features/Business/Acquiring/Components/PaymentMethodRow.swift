import SwiftUI

/// Component #3 — a selectable payment-method option row.
struct PaymentMethodRow: View {
    @Environment(\.theme) private var theme

    let method: PaymentMethod
    let detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm + 4) {
                GlyphCircle(systemImage: method.systemImage)

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                    Text(method.subtitle)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.sm)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(BrandFont.callout.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .animation(Motion.snappy, value: isSelected)
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(isSelected ? theme.accent : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct PaymentMethodRow_PreviewHost: View {
    @State private var selected: PaymentMethod = .sbp

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(PaymentMethod.allCases) { method in
                PaymentMethodRow(
                    method: method,
                    detail: method.feeLabel,
                    isSelected: selected == method,
                    action: { selected = method }
                )
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
    }
}

#Preview {
    PaymentMethodRow_PreviewHost()
        .environment(\.theme, .default)
}
