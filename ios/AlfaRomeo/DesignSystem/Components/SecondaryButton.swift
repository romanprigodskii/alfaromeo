import SwiftUI

/// Quieter action (docs/DESIGN.md §5): `fill` background, ink text, same metrics as ``PrimaryButton``.
/// Text-only; `icon` is kept for source compatibility and not drawn.
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .foregroundStyle(isEnabled ? theme.textPrimary : theme.textTertiary)
                .background(theme.fill)
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
    }
}

/// Plain accent text action (docs/DESIGN.md §5), e.g. «Подробнее», «Отменить».
struct TertiaryButton: View {
    let title: String
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.body(17, weight: .medium))
                .foregroundStyle(isEnabled ? theme.accent : theme.textTertiary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SecondaryButton(title: "Подробнее") {}
        SecondaryButton(title: "Недоступно") {}.disabled(true)
        TertiaryButton("Отменить") {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
