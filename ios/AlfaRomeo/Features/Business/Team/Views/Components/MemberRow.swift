import SwiftUI

/// A roster row: avatar, name (+ «вы» tag for the current user), role badge, optional chevron.
struct MemberRow: View {
    let member: TeamMember
    var showsChevron: Bool = true

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.md) {
            Avatar(initials: member.initials, size: 40,
                   ringColor: member.isCurrentUser ? theme.accent : nil)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    Text(member.name)
                        .font(BrandFont.bodyM.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                    if member.isCurrentUser {
                        Text("вы").font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(theme.elevated, in: Capsule())
                    }
                }
                Text(member.email).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            RoleBadge(role: member.role, compact: true)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }
}
