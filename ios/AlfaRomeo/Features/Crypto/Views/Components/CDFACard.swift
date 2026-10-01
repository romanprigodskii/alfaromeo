import SwiftUI

/// A ЦФА instrument row for the catalog (§9.6 🆕): category glyph, name, эмитент, price in ₽ and
/// the day change; доходность and the holding (if any) as data in the subtitle. A grouped-list row
/// (docs/DESIGN.md §4); the regulated status is stated once above the list (``LegalBadge``), and
/// оператор ИС is on the detail screen.
struct CDFACard: View {
    let cdfa: CDFA
    var holdingUnits: Double = 0
    var onTap: () -> Void = {}

    @Environment(\.theme) private var theme

    private var owned: Bool { holdingUnits > 0 }

    /// One fact after the issuer: the holding if owned, else the yield if any.
    private var subtitle: String {
        if owned { return "\(cdfa.issuer), в портфеле \(CryptoFormat.qty(holdingUnits))" }
        if cdfa.yieldPct > 0 { return "\(cdfa.issuer), \(cdfa.yieldLabel)" }
        return cdfa.issuer
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ListRow.glyphSpacing) {
                AssetGlyph(symbol: cdfa.ticker, systemImage: cdfa.category.icon, size: ListRow.glyphSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cdfa.name)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CryptoFormat.rub(cdfa.priceRub, fraction: 0))
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text(CryptoFormat.pct(cdfa.dayChangePct))
                        .font(BrandFont.subheadline)
                        .foregroundStyle(cdfa.dayChangePct >= 0 ? theme.success : theme.danger)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}

#Preview {
    GroupedSection { CDFACard(cdfa: MockCryptoData.cdfas[1], holdingUnits: 40) }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
