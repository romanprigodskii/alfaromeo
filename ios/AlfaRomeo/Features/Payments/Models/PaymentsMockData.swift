import Foundation

/// Payments-only demo fixtures (§9.2 / §10.3). Lives inside the Payments module so the network
/// ``MockData`` stays untouched: contacts, billers (ЖКУ/ГАИ/поставщики), offers, templates,
/// автоплатежи, plus the limit constants that drive the edge-case gates.
enum PaymentsMockData {

    // MARK: Contacts (СБП / crypto)

    static let contacts: [PaymentContact] = [
        PaymentContact(id: "c1", name: "Иван Петров",   phone: "+7 916 200-11-22", bank: "Альфа-Ромео", walletShort: "0x9f…A21c"),
        PaymentContact(id: "c2", name: "Мария Соколова", phone: "+7 925 304-55-67", bank: "Т-Банк",     walletShort: "TQ…rXm"),
        PaymentContact(id: "c3", name: "Артём Лебедев",  phone: "+7 903 777-08-09", bank: "Сбер",       walletShort: "bc1q…h2k9"),
        PaymentContact(id: "c4", name: "Ольга Кузнецова", phone: "+7 999 123-45-67", bank: "Альфа-Ромео", hasWallet: false),
        PaymentContact(id: "c5", name: "Дмитрий Орлов",  phone: "+7 911 444-22-00", bank: "ВТБ",        walletShort: "5H…uR9"),
    ]

    // MARK: Billers

    static let utilities: [Biller] = [
        Biller(id: "u1", name: "МосЭнергоСбыт", detail: "Лиц. счёт 402-118-336", icon: "bolt.fill", categoryId: "cat_utilities", suggestedAmount: 2_480, tintHex: 0xF2B441),
        Biller(id: "u2", name: "Мосводоканал",  detail: "Лиц. счёт 77-9920-014", icon: "drop.fill", categoryId: "cat_utilities", suggestedAmount: 1_120, tintHex: 0x4F7CFF),
        Biller(id: "u3", name: "МОЭК · отопление", detail: "Лиц. счёт 50-110-882", icon: "flame.fill", categoryId: "cat_utilities", suggestedAmount: 3_640, tintHex: 0xF5455C),
        Biller(id: "u4", name: "Ростелеком",    detail: "Договор 8-800-100-0800", icon: "wifi", categoryId: "cat_internet", suggestedAmount: 700),
    ]

    static let fines: [Biller] = [
        Biller(id: "f1", name: "Штраф ГИБДД · ст. 12.9", detail: "УИН 188 1 0477 2200 014", icon: "car.fill", categoryId: "cat_fines", suggestedAmount: 750, tintHex: 0xF5455C),
        Biller(id: "f2", name: "Штраф ГИБДД · парковка", detail: "УИН 035 6 0420 1190 882", icon: "parkingsign", categoryId: "cat_fines", suggestedAmount: 2_500, tintHex: 0xF2B441),
    ]

    static let myPayments: [Biller] = [
        Biller(id: "m1", name: "Ромео Mobile", detail: "+7 999 123-45-67", icon: "antenna.radiowaves.left.and.right", suggestedAmount: 600),
        Biller(id: "m2", name: "Яндекс Плюс",  detail: "Подписка · ежемесячно", icon: "play.circle.fill", suggestedAmount: 399),
        Biller(id: "m3", name: "Детский сад №14", detail: "Лиц. счёт 14-2035-07", icon: "figure.child", suggestedAmount: 5_200),
    ]

    // MARK: Suppliers (поиск + категории)

    static let supplierCategories: [BillerCategory] = [
        BillerCategory(id: "cat_utilities", name: "ЖКХ", icon: "house.fill"),
        BillerCategory(id: "cat_internet",  name: "Связь и интернет", icon: "wifi"),
        BillerCategory(id: "cat_fines",     name: "Штрафы и налоги", icon: "building.columns.fill"),
        BillerCategory(id: "cat_edu",       name: "Образование", icon: "graduationcap.fill"),
        BillerCategory(id: "cat_charity",   name: "Благотворительность", icon: "heart.fill"),
        BillerCategory(id: "cat_games",     name: "Игры и сервисы", icon: "gamecontroller.fill"),
    ]

    static let suppliers: [Biller] = utilities + myPayments + [
        Biller(id: "s1", name: "ИП Сидоров · ремонт", detail: "ИНН 770512345678", icon: "wrench.and.screwdriver.fill", categoryId: "cat_utilities"),
        Biller(id: "s2", name: "ООО Поставщик", detail: "ИНН 7709876543", icon: "shippingbox.fill", categoryId: "cat_utilities"),
        Biller(id: "s3", name: "Онлайн-школа Кодиум", detail: "ИНН 7726110055", icon: "graduationcap.fill", categoryId: "cat_edu", suggestedAmount: 12_900),
        Biller(id: "s4", name: "Фонд «Линия жизни»", detail: "ИНН 7704217419", icon: "heart.fill", categoryId: "cat_charity"),
        Biller(id: "s5", name: "Steam", detail: "Аккаунт romeo_2035", icon: "gamecontroller.fill", categoryId: "cat_games", suggestedAmount: 1_000),
    ]

    static func suppliers(in categoryId: String) -> [Biller] {
        suppliers.filter { $0.categoryId == categoryId }
    }

    /// Billers for one of the three quick-tile hubs (§9.2).
    static func billers(for section: BillerSection) -> [Biller] {
        switch section {
        case .myPayments: return myPayments
        case .utilities:  return utilities
        case .fines:      return fines
        }
    }

    /// Look up any biller by id across every hub + the suppliers directory (for ``payBiller`` routes).
    static func biller(id: String) -> Biller? {
        (utilities + fines + myPayments + suppliers).first { $0.id == id }
    }

    // MARK: Offers (§9.2): plain rows on the hub; the crypto / цифровой ₽ promos duplicated rails and were dropped

    static let offers: [PaymentOffer] = [
        PaymentOffer(id: "o1", title: "Переводы за рубеж без комиссии", subtitle: "Тариф Pro и выше", icon: "globe"),
        PaymentOffer(id: "o4", title: "Кэшбек 3\u{00A0}% на ЖКУ", subtitle: "При оплате до 10 числа", icon: "house.fill"),
    ]

    // MARK: Templates / autopayments

    static let templates: [PaymentTemplate] = [
        PaymentTemplate(id: "t1", title: "Маме на телефон", detail: "СБП · +7 916 200-11-22", kind: .byPhone, amount: 1_000,
                        recipientName: "Мама", phone: "+7 916 200-11-22"),
        PaymentTemplate(id: "t2", title: "Аренда квартиры", detail: "По реквизитам", kind: .byRequisites, amount: 65_000,
                        recipientName: "Смирнова Анна Викторовна", account: "40817810400012345678", bik: "044525593"),
        PaymentTemplate(id: "t3", title: "USDT Артёму", detail: "Крипто-перевод контакту", kind: .cryptoToContact, amount: nil,
                        contactId: "c3"),
    ]

    static let autopayments: [Autopayment] = [
        Autopayment(id: "a1", title: "Ромео Mobile", detail: "Пополнение номера", amount: 600, schedule: .monthly, nextDate: "2035-07-01", icon: "antenna.radiowaves.left.and.right"),
        Autopayment(id: "a2", title: "Яндекс Плюс", detail: "Подписка", amount: 399, schedule: .monthly, nextDate: "2035-06-15", icon: "play.circle.fill"),
        Autopayment(id: "a3", title: "Пополнение накоплений", detail: "При остатке < 10 000 ₽", amount: 5_000, schedule: .byThreshold, nextDate: "по событию", isOn: false, icon: "chart.line.uptrend.xyaxis"),
    ]

    // MARK: Limits (edge-case gates, §2.4 / §10.3)

    /// Per-operation limit by rail (₽). Crypto is governed by the неквал-инвестор лимит instead.
    /// The СБП/card cap sits *above* the default current-account balance (184 200 ₽) on purpose, so
    /// both the «лимит операции» gate AND the «недостаточно средств» decline are reachable on the
    /// showcase rail (amounts 184 200–200 000 ₽ decline at settlement; above 200 000 ₽ hit the gate).
    static func perOperationLimit(for kind: TransferKind) -> Double? {
        switch kind {
        case .byPhone:         return 200_000
        case .byCard:          return 200_000
        case .abroad:          return 1_000_000
        case .digitalRubleQR:  return 300_000
        case .betweenAccounts: return nil          // свои счета — без лимита
        case .byRequisites:    return nil
        case .cryptoToContact: return nil          // governed by investor limit below
        }
    }

    /// Неквал-инвестор: 300 000 ₽/год через посредника (§2.4). Already used this year (mock), so a
    /// modest crypto-перевод can tip it over — drives the «превышение лимита неквал» gate.
    static let nonQualYearlyLimitRub: Double = 300_000
    /// Fixed per-session baseline (demo): the gate is enforced per-operation on top of this, not as a
    /// cumulative running total — successive small crypto sends do not accumulate against it.
    static let nonQualUsedThisYearRub: Double = 280_000
    static var nonQualRemainingRub: Double { max(0, nonQualYearlyLimitRub - nonQualUsedThisYearRub) }
}
