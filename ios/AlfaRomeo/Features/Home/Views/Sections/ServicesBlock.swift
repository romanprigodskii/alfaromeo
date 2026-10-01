import SwiftUI

/// «Сервисы» (§9.1): the pre-approved credit (§10.5), Выгода и кэшбек (§9.3) and Ромео Mobile (§9.7)
/// as rows in one grouped list, each subtitle carrying its number. Credit is shown to adults only;
/// Mobile only when the profile has a plan.
struct ServicesBlock: View {
    let preApprovedCredit: Double?
    let mobilePlan: MobilePlan?
    var onCredit: () -> Void
    var onBenefits: () -> Void
    var onMobile: () -> Void

    var body: some View {
        GroupedSection("Сервисы") {
            if let amount = preApprovedCredit {
                Button(action: onCredit) {
                    ListRow(icon: "banknote", title: "Кредит наличными",
                            subtitle: "Предодобрено до \(MoneyFormat.compact(amount))",
                            showsChevron: true)
                }
                .buttonStyle(.row)
            }

            // Выгода и кэшбек moved off the personal tab bar («Биржа» took its slot) to this row;
            // it opens the unchanged BenefitsView via HomeRoute.benefits.
            Button(action: onBenefits) {
                ListRow(icon: "percent", title: "Выгода и кэшбек",
                        subtitle: "Категории, партнёры и подписка", showsChevron: true)
            }
            .buttonStyle(.row)

            if let plan = mobilePlan {
                Button(action: onMobile) {
                    ListRow(icon: "antenna.radiowaves.left.and.right", title: "Ромео Mobile",
                            subtitle: mobileSubtitle(plan), showsChevron: true)
                }
                .buttonStyle(.row)
            }
        }
    }

    /// `Осталось 12,5 из 30 ГБ · пакет M`
    private func mobileSubtitle(_ plan: MobilePlan) -> String {
        let remaining = max(0, plan.dataGb - plan.usedGb)
        let left = MoneyFormat.number(remaining, maxFractionDigits: 1)
        let total = MoneyFormat.number(plan.dataGb, maxFractionDigits: 1)
        return "Осталось \(left) из \(total)\u{00A0}ГБ · пакет \(plan.tariff)"
    }
}
