import SwiftUI

/// A toggle row for a ``GroupedSection``: optional monochrome glyph, title, data subtitle, switch.
struct SettingsToggleRow: View {
    var icon: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: ListRow.glyphSpacing) {
                if let icon { GlyphCircle(systemImage: icon, size: ListRow.glyphSize) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .tint(theme.accent)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: subtitle == nil ? Spacing.rowMinHeight : Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(icon == nil ? 0 : ListRow.glyphSize + ListRow.glyphSpacing)
    }
}
