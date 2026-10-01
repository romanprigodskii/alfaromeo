import SwiftUI

/// Circular avatar: initials or an SF Symbol on a neutral `fill` circle, with an optional context ring.
struct Avatar: View {
    var initials: String? = nil
    var systemImage: String? = nil
    var size: CGFloat = 44
    var ringColor: Color? = nil

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Circle().fill(theme.fill)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
            } else {
                Text(initials ?? "")
                    .font(BrandFont.body(size * 0.36, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 2)
        )
        .accessibilityLabel(initials ?? "Аватар")
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        Avatar(initials: "АР")
        Avatar(systemImage: "person.fill")
        Avatar(initials: "PRO", ringColor: Theme.default.accent)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
