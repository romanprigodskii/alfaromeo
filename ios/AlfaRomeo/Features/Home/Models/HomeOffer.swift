import SwiftUI

/// Offer-carousel categories (§9.1 «Тревел / Страхование / Инвестиции / Игры»). Each carries its own
/// glossy gradient so the shelf reads like Alfa's offer cards (§13.1 «глянцевые карточки»).
enum OfferCategory: String, CaseIterable, Identifiable {
    case travel, insurance, investments, games
    var id: String { rawValue }

    var title: String {
        switch self {
        case .travel:      return "Тревел"
        case .insurance:   return "Страхование"
        case .investments: return "Инвестиции"
        case .games:       return "Игры"
        }
    }

    var icon: String {
        switch self {
        case .travel:      return "airplane"
        case .insurance:   return "shield.lefthalf.filled"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .games:       return "gamecontroller.fill"
        }
    }

    /// Glossy gradient stops — brand artwork, intentionally not theme-semantic.
    var gradient: [Color] {
        switch self {
        case .travel:      return [Color(hex: 0x1FA2FF), Color(hex: 0x12D8C3)]
        case .insurance:   return [Color(hex: 0x11998E), Color(hex: 0x38EF7D)]
        case .investments: return [Color(hex: 0x5B4BFF), Color(hex: 0x9D50FF)]
        case .games:       return [Color(hex: 0xFF5E7E), Color(hex: 0xFF9D52)]
        }
    }
}

/// A single glossy offer card (§9.1). These are static marketing tiles.
struct HomeOffer: Identifiable {
    let id: String
    let category: OfferCategory
    let title: String
    let subtitle: String

    /// Demo offer shelf spanning all four categories (§9.1).
    static let catalog: [HomeOffer] = [
        HomeOffer(id: "of_travel",  category: .travel,      title: "Лаунж-доступ",            subtitle: "Бесплатно на Infinite"),
        HomeOffer(id: "of_invest",  category: .investments, title: "Стартовый портфель",      subtitle: "ИИ соберёт под цель"),
        HomeOffer(id: "of_ins",     category: .insurance,   title: "Страховка в поездку",     subtitle: "от 90 ₽ / день"),
        HomeOffer(id: "of_games",   category: .games,       title: "Кэшбек 10% на игры",      subtitle: "Steam · PS · Epic"),
        HomeOffer(id: "of_travel2", category: .travel,      title: "Авиабилеты −7%",          subtitle: "милями Ромео"),
        HomeOffer(id: "of_invest2", category: .investments, title: "Крипто-стейкинг",         subtitle: "до 12% годовых"),
    ]
}
