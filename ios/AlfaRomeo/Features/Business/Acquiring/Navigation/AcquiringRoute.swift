import SwiftUI

/// Navigation routes owned by the Эквайринг module (§8.2). Pushed onto the business «Эквайринг»
/// section's `NavigationStack` (registered in ``AcquiringHubView`` via
/// `.navigationDestination(for: AcquiringRoute.self)`), so the whole feature is self-contained:
/// wiring it from the business tab bar is a one-liner — `BusinessTab.acquiring` → `AcquiringHubView()`.
enum AcquiringRoute: Hashable {
    case createLink(PaymentLink.Kind)   // создать линк или QR
    case linkResult(PaymentLink)        // готовый линк/QR + шаринг
    case acceptPayment                  // демо-сценарий приёма оплаты
    case revenue                        // отчёт по выручке
}

extension AcquiringRoute {
    /// Destination for each route, owned by the Acquiring module.
    @ViewBuilder var destination: some View {
        switch self {
        case .createLink(let kind): CreatePaymentLinkView(kind: kind)
        case .linkResult(let link): PaymentLinkResultView(link: link)
        case .acceptPayment:        AcceptPaymentView()
        case .revenue:              RevenueReportView()
        }
    }
}
