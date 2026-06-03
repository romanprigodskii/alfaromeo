import SwiftUI

/// One tier in the comparison screen — name, price, the §4.1 matrix rows, and a select button.
struct TierCard: View {
    let entitlements: Entitlements
    let isCurrent: Bool
    let onSelect: () -> Void

    @Environment(\.theme) private var theme

    private var tier: Tier { entitlements.tier }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    Text(tier.priceLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if isCurrent { Badge(kind: .text("Текущий"), tint: theme.accent) }
            }

            VStack(spacing: 0) {
                row("Кэшбек", entitlements.cashback.label)
                divider
                row("Карты", entitlements.maxCardsLabel)
                divider
                row("AI-копилот", entitlements.aiLimitLabel)
                divider
                row("Крипта", entitlements.cryptoSpread.label)
                divider
                row("Ромео Mobile", entitlements.mobilePackage.label)
                divider
                row("Поддержка", entitlements.support.label)
                divider
                row("Тревел", entitlements.travel.label)
            }

            Button(action: onSelect) {
                Text(isCurrent ? "Активно" : (entitlements.tier.rank > 0 ? "Выбрать тариф" : "Перейти на базовый"))
                    .font(BrandFont.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .foregroundStyle(isCurrent ? theme.textSecondary : theme.onAccent)
                    .background(isCurrent ? AnyShapeStyle(theme.elevated) : AnyShapeStyle(theme.accent),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isCurrent)
        }
        .padding(Spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(isCurrent ? theme.accent : theme.border, lineWidth: isCurrent ? 2 : 1)
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.xs)
    }

    private var divider: some View { Divider().overlay(theme.border) }
}
