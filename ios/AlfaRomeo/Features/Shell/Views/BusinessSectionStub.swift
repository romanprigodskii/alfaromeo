import SwiftUI

/// Placeholder root for a business tab (§9.9). Renders the section's information architecture via
/// ``PlaceholderScreen`` and exercises the section ``Router`` with a demo push. Phase 4 replaces
/// these with the real business views; until then this keeps business mode navigable.
struct BusinessSectionStub: View {
    let content: SectionContent
    var isPrimary = false

    @Environment(Router.self) private var router

    var body: some View {
        PlaceholderScreen(
            title: "",
            blurb: content.blurb,
            items: content.items,
            showsScopedSummary: isPrimary,
            onPushDemo: {
                router.push(PlaceholderRoute(
                    title: "Раздел · детально",
                    blurb: "Экран открыт через NavigationStack и Router этой секции (§9). «Назад» возвращает в корень."
                ))
            }
        )
        .navigationDestination(for: PlaceholderRoute.self) { route in
            PlaceholderScreen(title: route.title, blurb: route.blurb)
                .navigationTitle(route.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
