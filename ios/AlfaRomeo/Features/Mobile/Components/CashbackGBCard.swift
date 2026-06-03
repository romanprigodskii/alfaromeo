import SwiftUI

/// Кэшбек гигабайтами (§7.1): «траты по карте → ГБ». Shows accrued GB (mono), the tier-linked monthly
/// rate, and a «Зачислить в пакет» action that credits the earned GB as bonus data.
struct CashbackGBCard: View {
    let cashback: MobileCashback
    var onCredit: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "gift.fill").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                    Text("Кэшбек гигабайтами").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }

                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(cashback.earnedLabel).font(BrandFont.mono(28, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(cashback.perMonthLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                }

                Text("Покупки по карте возвращаются гигабайтами. Зачислите их в пакет или копите.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if cashback.creditedGb > 0 {
                    Label("Зачислено в пакет: \(cashback.creditedLabel)", systemImage: "checkmark.seal.fill")
                        .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.success)
                }

                SecondaryButton(title: "Зачислить в пакет", icon: "arrow.down.circle") { onCredit() }
                    .disabled(!cashback.hasEarned)
            }
        }
    }
}
