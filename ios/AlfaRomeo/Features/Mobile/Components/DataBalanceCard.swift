import SwiftUI

/// Остатки ГБ/минут + текущий тариф (§7.2 Mobile-хаб). The one summary card on the hub: MSISDN and
/// tariff, flat ``ProgressBar`` meters for data + minutes, and the roaming state. On the unlimited
/// (Infinite) tariff there is no cap, so it shows «Безлимит» instead of a progress fill (§7.1).
struct DataBalanceCard: View {
    let tariff: MobileTariff
    let usedGb: Double
    let usedMin: Int
    let bonusGb: Double
    let msisdn: String
    let roamingOn: Bool

    @Environment(\.theme) private var theme

    private var dataCap: Double? { tariff.dataGb.map { $0 + bonusGb } }
    private var minutesCap: Int? { tariff.minutes }
    private var remainingGb: Double? { dataCap.map { max(0, $0 - usedGb) } }
    private var remainingMin: Int? { minutesCap.map { max(0, $0 - usedMin) } }
    private var dataFraction: Double { dataCap.map { $0 > 0 ? min(1, usedGb / $0) : 0 } ?? 0 }
    private var minFraction: Double { minutesCap.map { $0 > 0 ? min(1, Double(usedMin) / Double($0)) : 0 } ?? 0 }

    private static let nbsp = "\u{00A0}"

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text(msisdn)
                        .font(BrandFont.headline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    Text(tariff.name)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                if tariff.isUnlimited {
                    unlimitedRow
                } else {
                    meter(title: "Интернет",
                          remaining: format(remainingGb ?? 0) + Self.nbsp + "ГБ",
                          total: "из" + Self.nbsp + format(dataCap ?? 0) + Self.nbsp + "ГБ",
                          fraction: dataFraction)
                    meter(title: "Минуты",
                          remaining: MoneyFormat.integer(remainingMin ?? 0) + Self.nbsp + "мин",
                          total: "из" + Self.nbsp + MoneyFormat.integer(minutesCap ?? 0) + Self.nbsp + "мин",
                          fraction: minFraction)
                }

                HStack(spacing: Spacing.sm) {
                    Text(roamingOn ? "Роуминг включён" : "Роуминг выключен")
                        .font(BrandFont.footnote)
                        .foregroundStyle(theme.textSecondary)
                    if bonusGb > 0 {
                        Spacer(minLength: Spacing.sm)
                        Text("+" + format(bonusGb) + Self.nbsp + "ГБ кэшбеком")
                            .font(BrandFont.footnote)
                            .monospacedDigit()
                            .foregroundStyle(theme.success)
                    }
                }
            }
        }
    }

    private var unlimitedRow: some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: "infinity")
            VStack(alignment: .leading, spacing: 2) {
                Text("Безлимитный интернет и минуты").font(BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                Text("Класс Infinite").font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func meter(title: String, remaining: String, total: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs + 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Spacer(minLength: Spacing.sm)
                Text(total).font(BrandFont.subheadline).monospacedDigit()
                    .foregroundStyle(theme.textSecondary)
            }
            Text("Осталось " + remaining)
                .font(BrandFont.headline)
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
            ProgressBar(value: fraction, height: 6)
        }
    }

    private func format(_ value: Double) -> String { MobileTariff.format(value) }
}
