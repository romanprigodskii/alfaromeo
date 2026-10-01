import SwiftUI

/// Offer categories (§9.1 «Тревел / Страхование / Инвестиции / Игры»). Each has a monochrome glyph
/// for its row in the offers list.
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
}

/// A single offer row (§9.1). Static marketing content; the subtitle carries the number.
struct HomeOffer: Identifiable {
    let id: String
    let category: OfferCategory
    let title: String
    let subtitle: String

    /// Demo offers spanning all four categories (§9.1).
    static let catalog: [HomeOffer] = [
        HomeOffer(id: "of_travel",  category: .travel,      title: "Лаунж-доступ",            subtitle: "Бесплатно с Infinite"),
        HomeOffer(id: "of_invest",  category: .investments, title: "Стартовый портфель",      subtitle: "Подбор активов под цель"),
        HomeOffer(id: "of_ins",     category: .insurance,   title: "Страховка в поездку",     subtitle: "От 90\u{00A0}₽ в день"),
        HomeOffer(id: "of_games",   category: .games,       title: "Кэшбек 10\u{00A0}% на игры",     subtitle: "Steam, PlayStation, Epic"),
        HomeOffer(id: "of_travel2", category: .travel,      title: "Авиабилеты −7\u{00A0}%",         subtitle: "При оплате милями Ромео"),
        HomeOffer(id: "of_invest2", category: .investments, title: "Крипто-стейкинг",         subtitle: "До 12\u{00A0}% годовых"),
    ]
}
