import SwiftUI

/// Карточка способа подключения eSIM (§7.1): QR / новый номер / MNP. Selectable.
struct ESIMMethodCard: View {
    let method: ESIMMethod
    let isSelected: Bool
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: method.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.onAccent : theme.accent)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? AnyShapeStyle(theme.accent)
                                           : AnyShapeStyle(theme.accent.opacity(0.14)),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text(method.subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(isSelected ? theme.accent : theme.border)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
