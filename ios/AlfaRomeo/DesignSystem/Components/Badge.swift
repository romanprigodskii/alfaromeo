import SwiftUI

/// Small badge (docs/DESIGN.md §5): a count, a text tag, or a dot. Caption 12 medium, radius 8.
///
/// A text badge is tinted only when `tint` is a status color (success / danger / warning); any other
/// tint (accent, legacy crypto) renders as a neutral `fill` tag, so tags never become decoration.
struct Badge: View {
    enum Kind: Equatable {
        case count(Int)
        case text(String)
        case dot
    }

    var kind: Kind
    var tint: Color? = nil

    @Environment(\.theme) private var theme

    @ViewBuilder
    var body: some View {
        switch kind {
        case .dot:
            Circle().fill(tint ?? theme.danger).frame(width: 8, height: 8)
        case .count(let n):
            let color = tint ?? theme.danger
            Text(n > 99 ? "99+" : "\(n)")
                .font(BrandFont.micro)
                .monospacedDigit()
                .foregroundStyle(color.bestOnColor)
                .padding(.horizontal, 6)
                .frame(minWidth: 18, minHeight: 18)
                .background(color, in: Capsule())
        case .text(let s):
            let role = theme.statusRole(of: tint)
            Text(s)
                .font(BrandFont.micro)
                .lineLimit(1)
                .foregroundStyle(role.map { theme.statusInk($0) } ?? theme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    role.map { statusColor($0).opacity(theme.isDark ? 0.22 : 0.14) } ?? theme.fill,
                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                )
        }
    }

    private func statusColor(_ role: Theme.StatusRole) -> Color {
        switch role {
        case .success: return theme.success
        case .danger:  return theme.danger
        case .warning: return theme.warning
        }
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        Badge(kind: .count(3))
        Badge(kind: .count(128))
        Badge(kind: .text("Pro"), tint: Theme.default.accent)
        Badge(kind: .text("Live"), tint: Theme.default.success)
        Badge(kind: .dot, tint: Theme.default.success)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
