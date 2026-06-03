import SwiftUI

/// A solid, contrast-safe chip naming a teammate's role (§8.2: владелец / бухгалтер / менеджер).
/// Uses ``RoleCatalog`` for the label + tint; text uses `bestOnColor` so it stays AA on any tint
/// (graphite/platinum/steel-blue/amber).
struct RoleBadge: View {
    let role: MembershipRole
    var compact: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        let tint = RoleCatalog.tint(role, theme: theme)
        HStack(spacing: Spacing.xxs) {
            Image(systemName: RoleCatalog.icon(role))
                .font(.system(size: compact ? 9 : 10, weight: .bold))
            Text(RoleCatalog.label(role))
                .font((compact ? BrandFont.micro : BrandFont.caption).weight(.semibold))
        }
        .foregroundStyle(tint.bestOnColor)
        .padding(.horizontal, compact ? Spacing.sm : Spacing.sm)
        .padding(.vertical, compact ? 2 : Spacing.xs)
        .background(tint, in: Capsule())
        .accessibilityLabel("Роль: \(RoleCatalog.label(role))")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        RoleBadge(role: .owner)
        RoleBadge(role: .accountant)
        RoleBadge(role: .manager)
        RoleBadge(role: .manager, compact: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.resolve(for: .business, scheme: .light).background)
    .environment(\.theme, .resolve(for: .business, scheme: .light))
}
