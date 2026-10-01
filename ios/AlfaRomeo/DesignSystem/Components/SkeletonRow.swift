import SwiftUI

/// Loading placeholder row (docs/DESIGN.md §5): `fill` shapes in the geometry of a ``ListRow``.
/// Static (no shimmer). Put several inside a ``GroupedSection`` while content loads.
struct SkeletonRow: View {
    var showsGlyph: Bool = true
    var showsSubtitle: Bool = true

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: ListRow.glyphSpacing) {
            if showsGlyph {
                Circle().fill(theme.fill).frame(width: ListRow.glyphSize, height: ListRow.glyphSize)
            }
            VStack(alignment: .leading, spacing: 6) {
                bar(width: 140, height: 12)
                if showsSubtitle { bar(width: 90, height: 10) }
            }
            Spacer(minLength: Spacing.sm)
            bar(width: 64, height: 12)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: showsSubtitle ? Spacing.rowMinHeightTwoLine : Spacing.rowMinHeight)
        .groupedRowTextInset(showsGlyph ? ListRow.glyphSize + ListRow.glyphSpacing : 0)
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(theme.fill)
            .frame(width: width, height: height)
    }
}

#Preview {
    GroupedSection("Счета") {
        SkeletonRow()
        SkeletonRow()
        SkeletonRow(showsSubtitle: false)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
