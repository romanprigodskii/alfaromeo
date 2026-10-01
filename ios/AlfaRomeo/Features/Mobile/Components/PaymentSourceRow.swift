import SwiftUI

/// Выбор счёта списания (§7.1 «с любого счёта (вкл. крипту)»). One ``PaymentSource`` (fiat / цифр.₽
/// account or crypto wallet) as a selectable ``GroupedSection`` row: currency glyph, title, balance,
/// trailing selection mark. Crypto sources carry a neutral «Крипта» tag.
struct PaymentSourceRow: View {
    let source: PaymentSource
    let isSelected: Bool
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: source.icon)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs + 2) {
                        Text(source.title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if source.isCrypto { Badge(kind: .text("Крипта")) }
                    }
                    Text(source.balanceLabel).font(BrandFont.subheadline).monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeightTwoLine, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
