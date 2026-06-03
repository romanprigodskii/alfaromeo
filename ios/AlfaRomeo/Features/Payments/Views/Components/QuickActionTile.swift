import SwiftUI

/// A square quick-action tile for the payments hub (§9.2 «быстрые плитки»): a tinted icon chip over
/// a title + short subtitle. Tappable; honors the profile theme.
struct QuickActionTile: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var tint: Color? = nil
    var action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                let color = tint ?? theme.accent
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.callout.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        QuickActionTile(icon: "star.fill", title: "Мои платежи", subtitle: "Сохранённые") {}
        QuickActionTile(icon: "house.fill", title: "Счета ЖКУ", subtitle: "Начисления") {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
