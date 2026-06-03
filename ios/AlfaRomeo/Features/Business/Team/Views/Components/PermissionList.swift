import SwiftUI

/// Renders the full ``TeamPermission`` set with an allow/deny tick for a given role (§8.2 «права»).
/// Used in the member detail and as a column primitive in the roles matrix.
struct PermissionList: View {
    let granted: Set<TeamPermission>
    var permissions: [TeamPermission] = TeamPermission.allCases

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(permissions.enumerated()), id: \.element.id) { index, perm in
                if index > 0 { Divider().overlay(theme.border) }
                let on = granted.contains(perm)
                HStack(spacing: Spacing.md) {
                    Image(systemName: perm.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? theme.accent : theme.textSecondary)
                        .frame(width: 26)
                    Text(perm.title)
                        .font(BrandFont.callout)
                        .foregroundStyle(on ? theme.textPrimary : theme.textSecondary)
                    Spacer(minLength: Spacing.sm)
                    Image(systemName: on ? "checkmark.circle.fill" : "minus.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(on ? (theme.isDark ? theme.success : BrandColors.successInkLight)
                                            : theme.textSecondary.opacity(0.6))
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }
}
