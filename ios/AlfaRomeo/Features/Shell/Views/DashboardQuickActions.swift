import SwiftUI

/// Dashboard entry points to the tier-aware screens (§4 / §6). Rendered on the primary tab so the
/// subscription comparison and the gated cards flow are reachable in the demo.
struct DashboardQuickActions: View {
    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection {
            NavigationLink {
                SubscriptionView()
            } label: {
                ListRow(icon: "crown", title: "Подписка и тариф",
                        subtitle: "Base, Pro, Infinite", showsChevron: true)
            }
            .buttonStyle(.row)

            NavigationLink {
                CardsView()
            } label: {
                ListRow(icon: "creditcard", title: "Карты профиля",
                        subtitle: "Заказ карт с учётом тарифа", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }
}
