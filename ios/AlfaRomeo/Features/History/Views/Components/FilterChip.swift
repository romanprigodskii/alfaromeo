import SwiftUI

/// A flat filter chip used as the label of the «Счета» / «Даты» menus in the feed header.
/// Neutral `fill` at rest; an active (non-default) value inverts to ink so the state reads at a glance
/// without tinting the header in accent.
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var isActive: Bool = false
    var showsChevron: Bool = true

    @Environment(\.theme) private var theme

    private var fg: Color { isActive ? theme.background : theme.textPrimary }
    private var bg: Color { isActive ? theme.textPrimary : theme.fill }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if let icon {
                Image(systemName: GlyphCircle.outlineSymbol(icon)).font(.system(size: 13, weight: .regular))
            }
            Text(title).font(BrandFont.subheadline).lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
            }
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        FilterChip(title: "Счета")
        FilterChip(title: "Этот месяц", isActive: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
