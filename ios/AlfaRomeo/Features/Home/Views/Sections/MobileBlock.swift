import SwiftUI

/// Ромео Mobile teaser (§9.1, §7): remaining GB + tariff + cashback hint. Opens the Mobile hub stub
/// (``HomeRoute.mobile``).
struct MobileBlock: View {
    let plan: MobilePlan
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    private var remainingGb: Double { max(0, plan.dataGb - plan.usedGb) }
    private var usedFraction: Double { plan.dataGb > 0 ? plan.usedGb / plan.dataGb : 0 }

    var body: some View {
        DashboardSection(title: "Ромео Mobile", actionTitle: "Открыть", action: onTap) {
            Button(action: onTap) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.accent)
                            Text(plan.msisdn).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Badge(kind: .text("Пакет \(plan.tariff)"), tint: theme.accent)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Text("\(format(remainingGb)) ГБ осталось")
                                    .font(BrandFont.body(15, weight: .medium)).foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text("из \(format(plan.dataGb)) ГБ")
                                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                            }
                            ProgressBar(value: usedFraction, height: 8)
                        }

                        Text("Кэшбек гигабайтами за покупки по карте (§7.1).")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
