import SwiftUI

/// A standard list row: optional leading icon chip, title + optional subtitle, optional trailing
/// value and chevron. The common building block for hubs, settings, and account lists.
struct ListRow: View {
    var icon: String? = nil
    var iconTint: Color? = nil
    var title: String
    var subtitle: String? = nil
    var value: String? = nil
    var showsChevron: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let icon {
                let tint = iconTint ?? theme.accent
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }

            Spacer(minLength: Spacing.sm)

            if let value {
                Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        ListRow(icon: "creditcard", title: "Карта ··4921", subtitle: "Виртуальная",
                value: "12 400 ₽", showsChevron: true)
        Divider().overlay(Theme.default.border)
        ListRow(icon: "antenna.radiowaves.left.and.right", title: "Ромео Mobile",
                subtitle: "Пакет M", value: "24 ГБ", showsChevron: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
