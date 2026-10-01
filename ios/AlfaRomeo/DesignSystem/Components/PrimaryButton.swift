import SwiftUI

/// The one primary action per screen (docs/DESIGN.md §5): accent fill, height 52, radius 14,
/// headline 17 semibold, `onAccent` text.
///
/// Buttons are text-only: the `icon` parameter is kept for source compatibility but is not drawn,
/// except `faceid`, which tells the user the action asks for biometrics.
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    private var active: Bool { isEnabled && !isLoading }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.onAccent)
                } else if icon == "faceid" {
                    Image(systemName: "faceid").font(.system(size: 17, weight: .medium))
                }
                Text(title).font(BrandFont.headline)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(isEnabled ? theme.onAccent : theme.textTertiary)
            .background(isEnabled ? theme.accent : theme.fill)
            .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!active)
        .accessibilityLabel(title)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PrimaryButton(title: "Перевести") {}
        PrimaryButton(title: "Подтвердить", icon: "faceid") {}
        PrimaryButton(title: "Загрузка", isLoading: true) {}
        PrimaryButton(title: "Недоступно") {}.disabled(true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
