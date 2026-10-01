import SwiftUI

/// Один тариф в списке (§7.2 Тарифы) as a ``GroupedSection``: name + class, spec rows, and an action
/// row. The tariff is bound to a tier (§7.1), so when the active tier is lower the action reads as an
/// upgrade («Перейти на …») rather than a free switch. Selecting applies the matching tier (§4.3).
struct TariffOptionCard: View {
    let tariff: MobileTariff
    let isCurrent: Bool
    let isLocked: Bool        // requires a higher tier than the active one
    var onSelect: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection {
            HStack(alignment: .center, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tariff.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("Класс \(tariff.requiredTier.displayName)").font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                if isCurrent { Badge(kind: .text("Текущий")) }
            }
            .frame(minHeight: Spacing.rowMinHeightTwoLine)

            ListRow(title: "Интернет", value: tariff.dataLabel)
            ListRow(title: "Минуты", value: tariff.minutesLabel)
            ListRow(title: "Роуминг", value: tariff.roamingIncluded ? "Включён" : "По запросу")
            ListRow(title: "Кэшбек",
                    value: "≈\u{00A0}" + MobileTariff.format(tariff.cashbackGbPerMonth) + "\u{00A0}ГБ в месяц")

            if !isCurrent {
                Button(action: onSelect) {
                    Text(buttonTitle)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.row)
            }
        }
    }

    private var buttonTitle: String {
        isLocked ? "Перейти на \(tariff.requiredTier.shortLabel)" : "Подключить тариф"
    }
}
