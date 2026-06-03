import SwiftUI

/// Один тариф в списке (§7.2 Тарифы). The tariff is bound to a tier (§7.1), so the card shows the
/// `requiredTier` and — when the active tier is lower — reads as a soft upgrade rather than a free
/// switch. The select action applies the matching tier (§4.3 instant activation).
struct TariffOptionCard: View {
    let tariff: MobileTariff
    let isCurrent: Bool
    let isLocked: Bool        // requires a higher tier than the active one
    var onSelect: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tariff.name).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                    Text("Тариф \(tariff.requiredTier.displayName)").font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if isCurrent { Badge(kind: .text("Текущий"), tint: theme.accent) }
            }

            VStack(spacing: 0) {
                specRow(icon: "wifi", label: "Интернет", value: tariff.dataLabel)
                divider
                specRow(icon: "phone.fill", label: "Минуты", value: tariff.minutesLabel)
                divider
                specRow(icon: tariff.roamingIncluded ? "airplane.circle.fill" : "airplane",
                        label: "Роуминг", value: tariff.roamingIncluded ? "Включён" : "По запросу")
                divider
                specRow(icon: "gift.fill", label: "Кэшбек",
                        value: "≈ \(MobileTariff.format(tariff.cashbackGbPerMonth)) ГБ/мес")
            }

            Button(action: onSelect) {
                Text(buttonTitle)
                    .font(BrandFont.headline)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .foregroundStyle(isCurrent ? theme.textSecondary : theme.onAccent)
                    .background(isCurrent ? AnyShapeStyle(theme.elevated) : AnyShapeStyle(theme.accent),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(isCurrent)
        }
        .padding(Spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            .stroke(isCurrent ? theme.accent : theme.border, lineWidth: isCurrent ? 2 : 1))
    }

    private var buttonTitle: String {
        if isCurrent { return "Активно" }
        return isLocked ? "Перейти на \(tariff.requiredTier.shortLabel)" : "Подключить тариф"
    }

    private func specRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accent).frame(width: 22)
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var divider: some View { Divider().overlay(theme.border) }
}
