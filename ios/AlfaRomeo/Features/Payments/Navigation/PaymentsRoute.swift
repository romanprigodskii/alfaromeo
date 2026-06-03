import SwiftUI

/// Navigation routes owned by the Платежи section (§9.2). Pushed onto the section ``Router`` and
/// resolved by ``PaymentsView``. The seven transfer rails + bill payments funnel into one
/// ``TransferFlowView`` (получатель → сумма → подтверждение → статус); the hubs/lists are their own
/// screens.
enum PaymentsRoute: Hashable {
    case transfer(TransferKind)           // переводы — recipient chosen in-flow
    case payBiller(billerId: String)      // ЖКУ / штраф / поставщик / шаблон → prefilled flow
    case section(BillerSection)           // Мои платежи / Счета ЖКУ / Штрафы ГАИ
    case suppliers                        // Платежи поставщикам (поиск + категории)
    case templates                        // Шаблоны / Автоплатежи
    case newTemplate                      // создание шаблона / автоплатежа
    case investorStatus                   // статус инвестора / лимиты / тест — из лимит-гейта (§2.4); Payments не пушит CryptoRoute
}

extension PaymentsRoute {
    /// Destination for each route, owned by the Payments module (§9.2 / §10.3).
    @ViewBuilder var destination: some View {
        switch self {
        case .transfer(let kind):
            TransferFlowView(kind: kind)
        case .payBiller(let id):
            if let biller = PaymentsMockData.biller(id: id) {
                // Bill payments settle by requisites (0% комиссия); the flow titles itself by biller.
                TransferFlowView(kind: .byRequisites, biller: biller)
            } else {
                RouteStubScreen(title: "Платёж", note: "Получатель не найден.")
            }
        case .section(let section):
            BillerListView(section: section)
        case .suppliers:
            SuppliersView()
        case .templates:
            TemplatesView()
        case .newTemplate:
            NewTemplateView()
        case .investorStatus:
            InvestorStatusView()
        }
    }
}
