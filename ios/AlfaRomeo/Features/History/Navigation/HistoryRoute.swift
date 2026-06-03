import SwiftUI

/// Navigation routes owned by the История section (§9.4). Pushed onto the section ``Router`` and
/// resolved by ``HistoryView``.
enum HistoryRoute: Hashable {
    case operationDetail(txId: String)  // Деталь операции (мерчант, категория, чек, «спросить AI»)
    case budgetAnalytics                // Аналитика бюджета (диаграмма, помесячно, AI-прогноз)
    case categories                     // Мои категории
    case addExpense                     // Добавить расход (ручной учёт)
    case reports                        // Отчёты / экспорт (PDF/CSV)
}

extension HistoryRoute {
    /// Destination for each route (§9.4).
    @ViewBuilder var destination: some View {
        switch self {
        case .operationDetail(let txId): OperationDetailView(txId: txId)
        case .budgetAnalytics:           BudgetAnalyticsView()
        case .categories:                CategoriesView()
        case .addExpense:                AddExpenseView()
        case .reports:                   ReportsView()
        }
    }
}
