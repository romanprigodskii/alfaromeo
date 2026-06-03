import SwiftUI

/// Small badge: a count, a text label, or a dot. For unread counts, statuses, and tier tags.
struct Badge: View {
    enum Kind: Equatable {
        case count(Int)
        case text(String)
        case dot
    }

    var kind: Kind
    var tint: Color? = nil

    @Environment(\.theme) private var theme

    private var color: Color { tint ?? theme.danger }

    @ViewBuilder
    var body: some View {
        switch kind {
        case .dot:
            Circle().fill(color).frame(width: 8, height: 8)
        case .count(let n):
            Text(n > 99 ? "99+" : "\(n)")
                .font(BrandFont.micro)
                .foregroundStyle(color.bestOnColor)   // contrast-safe on any tint (platinum/cyan too)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(minWidth: 18)
                .background(color, in: Capsule())
        case .text(let s):
            Text(s)
                .font(BrandFont.micro)
                .foregroundStyle(color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 3)
                .background(color.opacity(0.16), in: Capsule())
        }
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        Badge(kind: .count(3))
        Badge(kind: .count(128))
        Badge(kind: .text("PRO"), tint: Theme.default.accent)
        Badge(kind: .dot, tint: Theme.default.success)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
