import SwiftUI

/// A neutral chip naming a teammate's role (§8.2: владелец / бухгалтер / менеджер). Caption 12 medium
/// on `fill`, radius 8 (DESIGN §5): roles are labels, not states, so they carry no tint.
struct RoleBadge: View {
    let role: MembershipRole
    var compact: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        Text(RoleCatalog.label(role))
            .font(compact ? BrandFont.micro : BrandFont.footnote.weight(.medium))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, compact ? 3 : Spacing.xs)
            .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
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
