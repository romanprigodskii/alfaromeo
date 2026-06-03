import Foundation

/// A partner cashback offer (§9.3 «Предложения / партнёры»). Read-only mock catalog — logos are SF
/// Symbols, percentages are illustrative. `premium` offers are exclusive to Infinite
/// (`Entitlements.allCashbackCategories`, §4.1 «премиум-партнёры»).
struct PartnerOffer: Identifiable, Hashable, Sendable {
    let id: String
    let brand: String       // RU
    let logo: String        // SF Symbol
    let cashbackPct: Double  // %
    let blurb: String       // short RU
    let categoryId: String?  // links to CashbackCategory.id (filter pills)
    let premium: Bool        // true = Infinite-exclusive

    /// Offers visible at the given entitlements: premium offers only when `allCashbackCategories`.
    static func visible(for e: Entitlements) -> [PartnerOffer] {
        e.allCashbackCategories ? offers : offers.filter { !$0.premium }
    }

    static var premiumOffers: [PartnerOffer] { offers.filter { $0.premium } }

    /// Distinct category IDs present in the catalog, in first-seen order — for the filter pills.
    static var filterCategoryIds: [String] {
        var seen = Set<String>()
        return offers.compactMap(\.categoryId).filter { seen.insert($0).inserted }
    }

    static let offers: [PartnerOffer] = [
        .init(id: "p_yandex",    brand: "Яндекс.Такси", logo: "car.fill",         cashbackPct: 10, blurb: "Кэшбек на каждую поездку",      categoryId: "cat_transport", premium: false),
        .init(id: "p_yaeda",     brand: "Яндекс.Еда",   logo: "fork.knife",       cashbackPct: 7,  blurb: "Доставка еды за 30 минут",      categoryId: "cat_food",      premium: false),
        .init(id: "p_ozon",      brand: "Ozon",         logo: "shippingbox.fill", cashbackPct: 5,  blurb: "Маркетплейс — миллионы товаров", categoryId: "cat_shops",     premium: false),
        .init(id: "p_wb",        brand: "Wildberries",  logo: "bag.fill",         cashbackPct: 4,  blurb: "Мода и товары для дома",         categoryId: "cat_shops",     premium: false),
        .init(id: "p_lenta",     brand: "Лента",        logo: "cart.fill",        cashbackPct: 3,  blurb: "Супермаркет у дома",            categoryId: "cat_super",     premium: false),
        .init(id: "p_apteka",    brand: "Аптека.ру",    logo: "cross.case.fill",  cashbackPct: 6,  blurb: "Лекарства с доставкой",         categoryId: "cat_pharmacy",  premium: false),
        .init(id: "p_kinopoisk", brand: "Кинопоиск",    logo: "play.circle.fill", cashbackPct: 5,  blurb: "Фильмы и сериалы",              categoryId: "cat_subs",      premium: false),
        .init(id: "p_aeroflot",  brand: "Аэрофлот",     logo: "airplane",         cashbackPct: 8,  blurb: "Авиабилеты по России и миру",   categoryId: "cat_travel",    premium: false),
        .init(id: "p_lukoil",    brand: "Лукойл",       logo: "fuelpump.fill",    cashbackPct: 9,  blurb: "Заправки по всей стране",       categoryId: "cat_fuel",      premium: false),
        .init(id: "p_ostrovok",  brand: "Островок",     logo: "bed.double.fill",  cashbackPct: 12, blurb: "Отели премиум-класса",         categoryId: "cat_travel",    premium: true),
        .init(id: "p_tsum",      brand: "ЦУМ",          logo: "crown.fill",       cashbackPct: 15, blurb: "Люкс-бутики и дизайнеры",       categoryId: "cat_lux",       premium: true),
    ]
}
