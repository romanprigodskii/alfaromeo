import SwiftUI

/// One tier in the comparison screen: name, price, the §4.1 matrix rows, and a select row.
struct TierCard: View {
    let entitlements: Entitlements
    let isCurrent: Bool
    let onSelect: () -> Void

    @Environment(\.theme) private var theme

    private var tier: Tier { entitlements.tier }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 2) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(tier.displayName).font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                if isCurrent { Badge(kind: .text("Текущий")) }
                Spacer(minLength: Spacing.sm)
                Text(tier.priceLabel).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }

            GroupedSection {
                row("Кэшбек", entitlements.cashback.label)
                row("Карты", entitlements.maxCardsLabel)
                row("AI-копилот", entitlements.aiLimitLabel)
                row("Крипта", entitlements.cryptoSpread.label)
                row("Ромео Mobile", entitlements.mobilePackage.label)
                row("Поддержка", entitlements.support.label)
                row("Путешествия", entitlements.travel.label)
                if !isCurrent {
                    Button(action: onSelect) {
                        Text(entitlements.tier.rank > 0 ? "Выбрать тариф" : "Перейти на базовый")
                            .font(BrandFont.headline)
                            .foregroundStyle(theme.accent)
                            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.rowVertical)
        .accessibilityElement(children: .combine)
    }
}
