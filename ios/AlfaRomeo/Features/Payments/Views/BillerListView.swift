import SwiftUI

/// Generic biller hub for the three quick actions (§9.2): Мои платежи, Счета ЖКУ, Штрафы ГАИ. Lists
/// the section's billers; tapping one opens the prefilled payment flow via ``PaymentsRoute/payBiller``.
struct BillerListView: View {
    let section: BillerSection

    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    private var billers: [Biller] { PaymentsMockData.billers(for: section) }

    var body: some View {
        ScrollView {
            GroupedSection(footer: section.blurb) {
                ForEach(billers) { biller in
                    Button { router.push(PaymentsRoute.payBiller(billerId: biller.id)) } label: {
                        ListRow(icon: biller.icon, title: biller.name, subtitle: biller.detail,
                                value: biller.suggestedAmount.map { MoneyFormat.fiat($0) }, showsChevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
