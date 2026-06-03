import SwiftUI

/// One РКО account row (§8.2): an icon chip, the account title + masked number, and the native balance
/// with a «≈ … ₽» live valuation sub-line for non-₽ accounts (multicurrency / stablecoin treasury).
struct AccountRow: View {
    let item: BusinessAccountItem

    @Environment(\.theme) private var theme

    private var iconTint: Color {
        // Treasury/stables read as a «cold» crypto surface (§13.1); ₽ and fiat keep the graphite accent.
        item.group == .treasury ? (theme.accentCrypto.last ?? theme.accent) : theme.accent
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 40, height: 40)
                .background(iconTint.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(BrandFont.bodyM.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Text(item.maskedNumber)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: item.balance,
                           currency: item.currency.uppercased() == "RUB" ? "₽" : item.currency.uppercased(),
                           size: 15)
                if item.showsRubEquivalent {
                    Text("≈ \(CryptoFormat.compactRub(item.rubValue))")
                        .font(BrandFont.micro)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }
}
