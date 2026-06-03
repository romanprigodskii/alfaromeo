import SwiftUI

/// A themed container surface with padding, rounded corners, and a hairline border.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elevated ? theme.elevated : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        SurfaceCard {
            Text("Surface").font(BrandFont.headline).foregroundStyle(Theme.default.textPrimary)
        }
        SurfaceCard(elevated: true) {
            Text("Elevated").font(BrandFont.headline).foregroundStyle(Theme.default.textPrimary)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
