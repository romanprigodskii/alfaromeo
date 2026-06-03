import SwiftUI

/// Personal-mode tab bar (§9): Главный · Платежи · Биржа · История · Чаты.
///
/// Each tab is an independent ``SectionScaffold`` (own Router/NavigationStack) wrapping the feature
/// module's root view. This mapping is the shell's last word on personal IA — Phase-1 modules fill
/// the *views*, not this file:
/// - Главный → ``HomeView`` (§9.1, prompt 1.1)
/// - Платежи → ``PaymentsView`` (§9.2, prompt 1.3)
/// - Биржа → ``CryptoHubView`` (§9.6 — the live-prices crypto/ЦФА exchange; `.cryptoHubChrome()` makes
///   the whole hub dark «проф-режим». Выгода (§9.3) moved to a dashboard block, `HomeRoute.benefits`.)
/// - История → ``HistoryView`` (§9.4, prompt 1.4)
/// - Чаты → ``ChatsHubView`` (§9.5 — AI-поддержка (Claude) channel + operators/обращения)
struct MainTabView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                SectionScaffold(title: tab.title) {
                    root(for: tab)
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
    }

    /// The root view for each personal tab. A stable type mapping — feature modules edit the view
    /// bodies, never this switch.
    @ViewBuilder
    private func root(for tab: AppTab) -> some View {
        switch tab {
        case .home:     HomeView()
        case .payments: PaymentsView()
        // §9.6 — the Crypto/ЦФА hub as a first-class tab. `.cryptoHubChrome()` (applied here, from
        // outside the view, like the other crypto entry point `HomeRoute.crypto`) makes the whole hub
        // dark «проф-режим»; the hub registers its own `CryptoRoute` destinations on this tab's stack.
        case .market:   CryptoHubView().cryptoHubChrome()
        case .history:  HistoryView()
        case .chats:    ChatsHubView()
        }
    }
}
