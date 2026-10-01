import SwiftUI

/// A standalone surface (docs/DESIGN.md §4): `surface` background, radius 16, no border, no shadow.
/// Use it only for a genuinely distinct object (a chart, a single primary summary); lists belong in
/// ``GroupedSection``. Never nest cards.
///
/// Legacy list idiom: `SurfaceCard(padding: Spacing.sm)` wrapping a stack of rows is what most screens
/// used as a list container. That padding is mapped to list insets (12pt sides, 4pt top/bottom) so rows
/// stop hugging the edge until the screen moves to ``GroupedSection`` (16pt rows on a 16pt margin).
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = Spacing.md
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.theme) private var theme

    private var insets: EdgeInsets {
        if padding == Spacing.sm {
            // Legacy list container: rows inside carry no side padding of their own.
            return EdgeInsets(top: Spacing.xs, leading: 12, bottom: Spacing.xs, trailing: 12)
        }
        return EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding)
    }

    var body: some View {
        content()
            .padding(insets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elevated ? theme.elevated : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
