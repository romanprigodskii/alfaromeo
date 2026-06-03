import SwiftUI

/// Tonal/outline secondary action — quieter than ``PrimaryButton``.
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(BrandFont.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(theme.textPrimary)
            .background(theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SecondaryButton(title: "Подробнее", icon: "chevron.up.circle") {}
        SecondaryButton(title: "Недоступно") {}.disabled(true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
