import SwiftUI

/// A corporate-card row: holder, type, masked tail, monthly-limit gauge (§8.2 «лимиты»). Dims when
/// frozen.
struct CorpCardRow: View {
    let card: CorporateCard

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.sm + 4) {
            GlyphCircle(systemImage: card.kind.icon)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Text(card.holderName).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(card.maskedPan).font(BrandFont.code(13)).foregroundStyle(theme.textSecondary)
                    if card.isFrozen {
                        Image(systemName: "snowflake").font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                ProgressBar(value: card.spentProgress, height: 4)
                Text("\(MoneyFormat.fiat(card.monthlySpent)) из \(MoneyFormat.fiat(card.monthlyLimit)) в месяц")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary).monospacedDigit()
            }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .opacity(card.isFrozen ? 0.6 : 1)
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .groupedRowTextInset(48)
    }
}
