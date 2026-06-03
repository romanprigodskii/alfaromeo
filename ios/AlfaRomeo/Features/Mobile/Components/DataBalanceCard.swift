import SwiftUI

/// Остатки ГБ/минут + текущий тариф (§7.2 Mobile-хаб). Shows the MSISDN, the tier-linked tariff
/// badge, animated ``ProgressBar`` for data + minutes, and a roaming chip. On the unlimited (Infinite)
/// tariff there is no cap — it shows «Безлимит» instead of a progress fill (§7.1).
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

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.accent)
                    Text(msisdn).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Spacer()
                    Badge(kind: .text(tariff.name), tint: theme.accent)
                }

                if tariff.isUnlimited {
                    unlimitedRow
                } else {
                    meter(title: "Интернет", remaining: "\(format(remainingGb ?? 0)) ГБ осталось",
                          total: "из \(format(dataCap ?? 0)) ГБ", fraction: dataFraction)
                    meter(title: "Минуты", remaining: "\(remainingMin ?? 0) мин осталось",
                          total: "из \(minutesCap ?? 0) мин", fraction: minFraction)
                }

                HStack(spacing: Spacing.sm) {
                    Label(roamingOn ? "Роуминг включён" : "Роуминг выкл.",
                          systemImage: roamingOn ? "airplane.circle.fill" : "airplane")
                        .font(BrandFont.caption.weight(.medium))
                        .foregroundStyle(roamingOn ? theme.accent : theme.textSecondary)
                    if bonusGb > 0 {
                        Spacer()
                        Text("+\(format(bonusGb)) ГБ кэшбек")
                            .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.success)
                    }
                }
            }
        }
    }

    private var unlimitedRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "infinity").font(.system(size: 22, weight: .bold)).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Безлимитный интернет и минуты").font(BrandFont.bodyM.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                Text("Тариф Infinite — без ограничений (§7.1)").font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
    }

    private func meter(title: String, remaining: String, total: String, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            HStack {
                Text(remaining).font(BrandFont.body(15, weight: .medium)).foregroundStyle(theme.textPrimary)
                Spacer()
                Text(total).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            ProgressBar(value: fraction, height: 8)
        }
    }

    private func format(_ value: Double) -> String { MobileTariff.format(value) }
}
