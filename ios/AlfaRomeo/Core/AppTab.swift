import Foundation

/// Personal-mode tab bar (§9: «Главный · Платежи · Биржа · История · Чаты»).
///
/// «Биржа» = the Crypto/ЦФА hub (§9.6) promoted to a first-class tab (live-prices exchange). «Выгода»
/// (§9.3) is no longer a tab — it moved to a dashboard block-entry (`HomeRoute.benefits`), keeping all
/// three cashback screens intact.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case payments
    case market
    case history
    case chats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "Главный"
        case .payments: return "Платежи"
        case .market:   return "Биржа"
        case .history:  return "История"
        case .chats:    return "Чаты"
        }
    }

    var systemImage: String {
        switch self {
        case .home:     return "house.fill"
        case .payments: return "arrow.left.arrow.right"
        case .market:   return "chart.line.uptrend.xyaxis"
        case .history:  return "clock.fill"
        case .chats:    return "bubble.left.and.bubble.right.fill"
        }
    }
}

/// Business-mode tab bar (§9.9: «Дашборд · Счета · Эквайринг · Команда · Чаты(AI)»).
enum BusinessTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard
    case accounts
    case acquiring
    case team
    case chats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Дашборд"
        case .accounts:  return "Счета"
        case .acquiring: return "Эквайринг"
        case .team:      return "Команда"
        case .chats:     return "Чаты"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .accounts:  return "building.columns.fill"
        case .acquiring: return "qrcode"
        case .team:      return "person.2.fill"
        case .chats:     return "bubble.left.and.bubble.right.fill"
        }
    }
}
