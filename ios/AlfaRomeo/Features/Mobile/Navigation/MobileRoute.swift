import SwiftUI

/// Navigation routes owned by the Ромео Mobile module (§7.2, §9.7). They are pushed onto the hub's
/// own `NavigationStack` (registered in ``MobileHubView``), so the whole feature is self-contained:
/// wiring it from the dashboard is a one-liner — `HomeRoute.mobile` → `MobileHubView()`.
///
/// Any Mobile screen can deep-link to another with `NavigationLink(value: MobileRoute.x)`; it resolves
/// on the same `.navigationDestination(for: MobileRoute.self)` the hub registers.
enum MobileRoute: Hashable {
    case esim                              // Подключение eSIM (QR / новый / MNP)
    case tariffs                           // Тарифы (связка с тиром) + смена
    case usage                             // Детализация / использование
    case roaming                           // Роуминг (+ крипто-оплата)
    case family                            // Семейный пакет
    case payment(MobilePaymentPurpose)     // Оплата связи (любой счёт / крипта)
}

extension MobileRoute {
    /// Destination for each route, owned by the Mobile module.
    @ViewBuilder var destination: some View {
        switch self {
        case .esim:           ESIMConnectView()
        case .tariffs:        TariffsView()
        case .usage:          UsageView()
        case .roaming:        RoamingView()
        case .family:         FamilyPlanView()
        case .payment(let p): MobilePaymentView(purpose: p)
        }
    }
}
