import Foundation

/// A cashback category the user can activate (§9.3 «Выбор категорий»). Each carries a base rate and,
/// where eligible, an elevated «супер-кэшбек» rate (§4 — повышенный кэшбек on Pro+). `premium`
/// categories unlock only on Infinite (`Entitlements.allCashbackCategories`).
struct CashbackCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String        // RU
    let icon: String        // SF Symbol
    let baseRate: Double    // %
    let superRate: Double?  // elevated % (nil = not super-eligible)
    let premium: Bool       // true = Infinite-only

    static func lookup(_ id: String) -> CashbackCategory? { catalog.first { $0.id == id } }

    /// Format a percentage rate the brand way — trimmed decimals + «%» (e.g. 1.5 → "1,5%", 5.0 → "5%").
    static func pct(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    /// The cashback catalog (§9.3). Mock content — there is no API for this.
    static let catalog: [CashbackCategory] = [
        .init(id: "cat_food",      name: "Кафе и рестораны", icon: "fork.knife",      baseRate: 1.5, superRate: 5.0,  premium: false),
        .init(id: "cat_travel",    name: "Путешествия",      icon: "airplane",        baseRate: 2.0, superRate: 8.0,  premium: false),
        .init(id: "cat_fuel",      name: "АЗС и топливо",    icon: "fuelpump.fill",   baseRate: 3.0, superRate: 7.0,  premium: false),
        .init(id: "cat_shops",     name: "Магазины",         icon: "bag.fill",        baseRate: 0.5, superRate: 3.0,  premium: false),
        .init(id: "cat_super",     name: "Супермаркеты",     icon: "cart.fill",       baseRate: 1.5, superRate: 4.5,  premium: false),
        .init(id: "cat_pharmacy",  name: "Аптеки",           icon: "cross.case.fill", baseRate: 2.0, superRate: 6.0,  premium: false),
        .init(id: "cat_subs",      name: "Подписки",         icon: "repeat.circle",   baseRate: 1.5, superRate: 6.0,  premium: false),
        .init(id: "cat_fun",       name: "Развлечения",      icon: "film.fill",       baseRate: 2.0, superRate: 7.0,  premium: false),
        .init(id: "cat_transport", name: "Транспорт",        icon: "tram.fill",       baseRate: 1.0, superRate: 4.0,  premium: false),
        .init(id: "cat_lux",       name: "Премиум-бутики",   icon: "crown.fill",      baseRate: 1.0, superRate: 10.0, premium: true),
    ]
}
