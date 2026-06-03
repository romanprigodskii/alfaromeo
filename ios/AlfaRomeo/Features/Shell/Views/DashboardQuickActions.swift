import SwiftUI

/// Dashboard entry points to the tier-aware screens (§4 / §6). Rendered on the primary tab so the
/// subscription comparison and the gated cards flow are reachable in the demo.
struct DashboardQuickActions: View {
    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                NavigationLink {
                    SubscriptionView()
                } label: {
                    ListRow(icon: "crown.fill", title: "Подписка и тариф",
                            subtitle: "Сравнить Base · Pro · Infinite", showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().overlay(theme.border)

                NavigationLink {
                    CardsView()
                } label: {
                    ListRow(icon: "creditcard", title: "Карты профиля",
                            subtitle: "Заказ карт с учётом тарифа", showsChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
