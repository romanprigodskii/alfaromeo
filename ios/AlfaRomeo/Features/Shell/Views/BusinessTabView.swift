import SwiftUI

/// Business-mode tab bar (§9.9): Дашборд · Счета · Эквайринг · Команда · Чаты(AI).
///
/// Each tab is a ``SectionScaffold`` (own Router/NavigationStack) wrapping a real §8.2 hub:
/// - **Дашборд** → ``BusinessDashboardView`` (баланс по счетам, кэшфлоу, задачи на подпись, AI-инсайт).
/// - **Счета** → ``BusinessAccountsView`` (РКО: рублёвые + мультивалютные + крипто-трежери по live-курсу).
/// - **Эквайринг** → ``AcquiringHubView`` (онлайн/QR/терминал + крипто-приём с авто-конвертацией в ₽).
/// - **Команда** → ``TeamHubView`` (роли/права, корп-карты, 2-of-N подписи).
/// - **Чаты(AI)** → ``AIAccountantView`` (AI-бухгалтер: 90-дневный прогноз кэшфлоу, предупреждение о
///   кассовом разрыве с суммой/датой, оптимизация налога, агентные счёт/оплата). It owns its own screen
///   (cards + stream + composer) and NavigationStack, so the personal floating-copilot FAB isn't laid
///   over the chat composer — the business AI *is* the chat here.
///
/// Each hub registers its OWN `navigationDestination`. The Дашборд reaches the other tabs (AI-инсайт →
/// Чаты, баланс → Счета, «Все» задачи → Команда) by setting `selection` through an `onSelectTab` closure
/// — no shared coordinator, the tab bar's own state stays the source of truth.
struct BusinessTabView: View {
    @State private var selection: BusinessTab = BusinessTabView.initialTab

    /// Demo/QA: preselect a tab via the `AR_BUSINESS_TAB` env var (e.g. `acquiring`); else Дашборд.
    private static var initialTab: BusinessTab {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["AR_BUSINESS_TAB"],
           let tab = BusinessTab(rawValue: raw) { return tab }
        #endif
        return .dashboard
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(BusinessTab.allCases) { tab in
                tabContent(tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: BusinessTab) -> some View {
        switch tab {
        case .chats:
            // The AI-бухгалтер supplies its own NavigationStack + composer (§8.2).
            AIAccountantView()
        default:
            SectionScaffold(title: tab.title) { root(for: tab) }
        }
    }

    @ViewBuilder
    private func root(for tab: BusinessTab) -> some View {
        switch tab {
        case .dashboard:
            BusinessDashboardView(onSelectTab: { selection = $0 })
        case .accounts:
            BusinessAccountsView()
        case .acquiring:
            AcquiringHubView()
        case .team:
            TeamHubView()
        default:
            BusinessSectionStub(content: SectionCatalog.business(tab),
                                isPrimary: tab == .dashboard)
        }
    }
}
