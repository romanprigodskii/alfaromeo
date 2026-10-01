import SwiftUI

/// Способ подключения eSIM (§7.1): QR / новый номер / MNP. A selectable row for a ``GroupedSection``:
/// monochrome glyph, title + subtitle, trailing selection mark.
struct ESIMMethodCard: View {
    let method: ESIMMethod
    let isSelected: Bool
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: method.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(method.subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeightTwoLine, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
