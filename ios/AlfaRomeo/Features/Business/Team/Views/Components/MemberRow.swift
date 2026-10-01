import SwiftUI

/// A roster row: avatar, name (+ «вы» tag for the current user), role badge, optional chevron.
struct MemberRow: View {
    let member: TeamMember
    var showsChevron: Bool = true

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm + 4) {
            Avatar(initials: member.initials, size: 36,
                   ringColor: member.isCurrentUser ? theme.accent : nil)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(member.name)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    if member.isCurrentUser {
                        Text("вы").font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                }
                Text(member.email).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            RoleBadge(role: member.role, compact: true)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(48)
    }
}
