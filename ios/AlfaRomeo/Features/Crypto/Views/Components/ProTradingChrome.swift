import SwiftUI

/// Scoped **dark «professional mode»** for the Crypto hub (§13.1). The bank ships light by default;
/// the *exchange* is the one place that goes dark, like a venue terminal — the whole hub now, not just
/// the trading detail (`биржа целиком тёмная`).
///
/// Applying this to a `NavigationStack` destination (or a tab root) flips just that stack item:
/// `.preferredColorScheme(.dark)` is scoped to the current item and reverts on pop, so the dashboard /
/// переводы / карты / история stay light. It re-resolves the **dark** theme from the *ambient* profile
/// type (so a business/joint/child context keeps its base) and keeps the brand **cold crypto gradient**
/// as the tint — never an exchange-orange.
///
/// Crucially it overrides `\.theme` itself, so screens reached *from* a dark surface inherit dark
/// semantic tokens too — which is exactly why the light operation flows below must explicitly reclaim
/// light with ``CryptoLightChrome`` (resetting `\.theme`, not only the window scheme).
private struct CryptoDarkChrome: ViewModifier {
    @Environment(\.theme) private var ambient

    func body(content: Content) -> some View {
        let dark = Theme.resolve(for: ambient.profileType, scheme: .dark)
        content
            .environment(\.theme, dark)                                   // semantic tokens → dark
            .tint(dark.accentCrypto.first ?? dark.accent)                 // cold accent, not orange
            .toolbarColorScheme(.dark, for: .navigationBar)               // title / back / avatar light-on-dark
            .toolbarBackground(dark.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)                                  // flips UIKit controls + status bar, scoped
    }
}

/// Explicit **light reclaim** for screens pushed out of the dark hub (Обмен / Отправить / Принять /
/// стейкинг). Because the hub overrides `\.theme` to dark and `.navigationDestination` children inherit
/// that, resetting only `.preferredColorScheme(.light)` (the window scheme) would leave the semantic
/// `\.theme` dark — light window, dark-coloured content. This resets **both**: the theme back to light
/// *and* the window scheme, so the screen is fully light and reverts the window cleanly on pop. (This is
/// the leak the §13.1 note warns about — light primary everywhere except the exchange surface itself.)
private struct CryptoLightChrome: ViewModifier {
    @Environment(\.theme) private var ambient

    func body(content: Content) -> some View {
        let light = Theme.resolve(for: ambient.profileType, scheme: .light)
        content
            .environment(\.theme, light)                                  // semantic tokens → light (the real fix)
            .tint(light.accent)
            .toolbarColorScheme(.light, for: .navigationBar)
            .preferredColorScheme(.light)                                 // reclaim a light window on top of dark
    }
}

extension View {
    /// Wrap a trading-detail screen (стакан / свечи / ордер) in the scoped dark professional mode.
    func proTradingChrome() -> some View { modifier(CryptoDarkChrome()) }

    /// Wrap the Crypto hub — and the exchange-side screens reached from it (актив / история сделок /
    /// статус инвестора / ЦФА / привязка кошелька) — in the dark «проф-режим». Same chrome as
    /// ``proTradingChrome()``; named for the hub-level intent (§9.6: биржа целиком тёмная).
    func cryptoHubChrome() -> some View { modifier(CryptoDarkChrome()) }

    /// Reclaim a fully light screen when pushed out of the dark hub — the money-movement flows
    /// (Обмен / Отправить / Принять / стейкинг) that must match the rest of the light banking app.
    func cryptoLightChrome() -> some View { modifier(CryptoLightChrome()) }
}
