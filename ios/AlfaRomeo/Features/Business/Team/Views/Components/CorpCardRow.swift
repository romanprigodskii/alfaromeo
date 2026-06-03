import SwiftUI

/// A corporate-card row: holder, type, masked tail, monthly-limit gauge (§8.2 «лимиты»). Dims when
/// frozen.
struct CorpCardRow: View {
    let card: CorporateCard

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(theme.accent.opacity(0.14))
                    .frame(width: 44, height: 32)
                Image(systemName: card.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text(card.holderName).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text(card.maskedPan).font(BrandFont.caption).foregroundStyle(theme.textSecondary).monospacedDigit()
                    if card.isFrozen {
                        Image(systemName: "snowflake").font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.accent)
                    }
                }
                ProgressBar(value: card.spentProgress, height: 6)
                Text("\(Self.rub(card.monthlySpent)) из \(Self.rub(card.monthlyLimit)) в месяц")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary).monospacedDigit()
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .opacity(card.isFrozen ? 0.6 : 1)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private static func rub(_ v: Double) -> String {
        (SupplierPaymentModel.formatter.string(from: NSNumber(value: v)) ?? "\(Int(v))") + " ₽"
    }
}
