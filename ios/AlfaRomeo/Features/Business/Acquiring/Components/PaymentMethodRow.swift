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
            HStack(spacing: Spacing.md) {
                Image(systemName: method.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        theme.accent.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(BrandFont.bodyM.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(method.subtitle)
                        .font(BrandFont.caption)
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
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : theme.border)
                    .animation(Motion.snappy, value: isSelected)
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent : theme.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
