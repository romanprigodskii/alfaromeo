import SwiftUI

/// Navigation routes owned by the Главная section (§9.1). Pushed onto the section ``Router`` and
/// resolved by ``HomeView`` via `.navigationDestination`. Phase 1.1 owns this file.
///
/// Cards live on the home dashboard (§9.1) but belong to the Cards module — those routes are
/// ``CardsRoute`` (1.2), resolved alongside `HomeRoute` in ``HomeView``. The product-hub routes
/// below (crypto / deposits / credits / mobile) resolve to stubs this phase; the owning modules
/// (Фаза 2) replace the destinations.
enum HomeRoute: Hashable {
    case accountDetail(accountId: String)  // Счёт (детейл)
    case openProduct                       // Открытие продукта
    case branches                          // Отделения / банкоматы
    case crypto                            // Крипто-кошелёк (хаб, §9.6)
    case deposits                          // Вклады / Стейкинг (§10.6)
    case credits                           // Кредит (§10.5)
    case mobile                            // Ромео Mobile (§9.7)
    case benefits                          // Выгода и кэшбек (§9.3 — moved off the tab bar to a dashboard block)

    var stubTitle: String {
        switch self {
        case .accountDetail: return "Счёт"
        case .openProduct:   return "Открытие продукта"
        case .branches:      return "Отделения и банкоматы"
        case .crypto:        return "Крипто-кошелёк"
        case .deposits:      return "Вклады и стейкинг"
        case .credits:       return "Кредит"
        case .mobile:        return "Ромео Mobile"
        case .benefits:      return "Выгода и кэшбек"
        }
    }

    /// Stub note with the §-reference for the module that fills this route later.
    fileprivate var stubNote: String {
        switch self {
        case .accountDetail: return "Детейл счёта соберёт следующий промпт (§9.1)."
        case .openProduct:   return "Витрина продуктов появится позже."
        case .branches:      return "Карта отделений и банкоматов появится позже."
        case .crypto:        return "Крипто-хаб соберёт Фаза 2 (§9.6)."
        case .deposits:      return "Вклады и стейкинг соберёт Фаза 2 (§10.6)."
        case .credits:       return "Кредиты с объяснимой преквалификацией (§10.5)."
        case .mobile:        return "Ромео Mobile (MVNO) соберёт Фаза 2 (§9.7)."
        case .benefits:      return "Выгода и кэшбек (§9.3)."
        }
    }
}

extension HomeRoute {
    /// Destination for each route. Owning modules swap these stubs for real screens.
    @ViewBuilder var destination: some View {
        switch self {
        case .crypto:
            // §9.6 — Crypto/ЦФА hub, owned by the Crypto module (Features/Crypto). This is the single
            // integration seam: the hub registers its own `CryptoRoute` destinations on the Home stack.
            // Light like the rest of the app (no special chrome — just the ambient DesignSystem theme).
            CryptoHubView()
        case .benefits:
            // §9.3 — Выгода/кэшбек hub. Moved off the personal tab bar to this dashboard block-entry; the
            // view is unchanged and its three screens push via its own destination-based `NavigationLink`s
            // onto this Home stack. Title supplied here (the view relied on the section scaffold before).
            BenefitsView()
                .navigationTitle("Выгода и кэшбек")
                .navigationBarTitleDisplayMode(.inline)
        case .deposits:
            // «Приумножить» — вклады + стейкинг (§10.6). The hub registers its own sub-routes.
            SavingsHubView()
        case .mobile:
            // §9.7 — Ромео Mobile hub, owned by the Mobile module. Registers its own `MobileRoute`
            // sub-flows on this Home stack (same one-stack pattern as the Crypto/Savings hubs).
            MobileHubView()
        case .credits:
            // §10.5 — Кредиты, owned by the Credit module (Features/Credit). Registers its own
            // `CreditRoute` (pre-qual / apply) destinations on this Home stack.
            CreditView()
        case .accountDetail(let accountId):
            // §9.1 / §10.2 — детейл одного счёта (баланс / реквизиты / операции по счёту). Owned here
            // in Features/Home; the screen registers `HistoryRoute` (деталь операции) and
            // `PaymentsRoute` (переводы) on this stack — same one-stack seam as crypto / credit.
            AccountDetailScreen(accountId: accountId)
        default:
            RouteStubScreen(title: stubTitle, note: stubNote)
        }
    }
}
