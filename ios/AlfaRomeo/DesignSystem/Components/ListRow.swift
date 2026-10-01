import SwiftUI

/// The standard list row (docs/DESIGN.md §5): optional leading glyph in a `fill` circle, title (body 17)
/// + optional subtitle (15, secondary), optional trailing value (17, tabular) and chevron.
///
/// Monochrome by design: `iconTint` is honoured only when it is the theme's `danger` color (a
/// destructive row); any other tint is ignored, so rows never get pastel tiles. For a meaningful
/// colored mark, build the row with ``GlyphCircle`` directly.
///
/// Horizontal padding comes from the container (``GroupedSection`` or a list ``SurfaceCard``). Inside
/// a ``GroupedSection`` the separator below the row is inset to the row's text column automatically.
struct ListRow: View {
    var icon: String? = nil
    var iconTint: Color? = nil
    var title: String
    var subtitle: String? = nil
    var value: String? = nil
    var showsChevron: Bool = false

    @Environment(\.theme) private var theme

    /// Trailing values that carry numbers read as data (ink); words («Светлая», «Вкл.») as metadata.
    private var valueIsNumeric: Bool { value?.contains(where: \.isNumber) ?? false }

    private var glyphTint: Color? {
        theme.statusRole(of: iconTint) == .danger ? theme.danger : nil
    }

    var body: some View {
        HStack(spacing: ListRow.glyphSpacing) {
            if let icon {
                GlyphCircle(systemImage: icon, size: ListRow.glyphSize, tint: glyphTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .multilineTextAlignment(.leading)

            Spacer(minLength: Spacing.sm)

            if let value {
                Text(value)
                    .font(BrandFont.body(17))
                    .monospacedDigit()
                    .foregroundStyle(valueIsNumeric ? theme.textPrimary : theme.textSecondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: subtitle == nil ? Spacing.rowMinHeight : Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(icon == nil ? 0 : ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }

    /// Leading glyph circle diameter.
    static let glyphSize: CGFloat = 36
    /// Gap between the glyph and the text column.
    static let glyphSpacing: CGFloat = 12
}

#Preview {
    GroupedSection("Счета") {
        ListRow(icon: "creditcard", title: "Карта •• 4921", subtitle: "Виртуальная",
                value: "12 400 ₽", showsChevron: true)
        ListRow(icon: "antenna.radiowaves.left.and.right", title: "Ромео Mobile",
                subtitle: "Пакет M", value: "24 ГБ", showsChevron: true)
        ListRow(title: "Тема", value: "Светлая", showsChevron: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
