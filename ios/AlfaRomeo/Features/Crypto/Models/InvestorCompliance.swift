import Foundation

/// Crypto compliance constants + the risk test (§2.4 / §10.8). These gate **crypto** only — ЦФА is
/// the legal 259-ФЗ path and is intentionally exempt (see ``CDFA``). The неквал-инвестор ceiling is
/// 300 000 ₽/year through an intermediary; the demo seeds a baseline close to the cap so a modest
/// trade tips it over and the «превышение лимита» gate is reachable, mirroring ``PaymentsMockData``.
enum CryptoCompliance {
    /// Неквал-инвестор годовой лимит, ₽ (§2.4).
    static let yearlyLimitRub: Double = 300_000
    /// Already used this year at session start (demo baseline). Kept in step with the Payments gate.
    static let seededUsedRub: Double = 280_000
}

/// One question of the «тест на риски» that gates a неквал investor's first crypto trade (§2.4).
struct RiskTestQuestion: Identifiable, Hashable, Sendable {
    let id: Int
    let prompt: String
    let options: [String]
    let correctIndex: Int
}

/// The risk-knowledge test shown once before a неквал investor's first crypto operation (§10.8).
/// Passing requires getting at least `passThreshold` of the questions right — informative, not a wall.
enum CryptoRiskTest {
    static let passThreshold = 3

    static let questions: [RiskTestQuestion] = [
        RiskTestQuestion(
            id: 1,
            prompt: "Что характерно для криптовалют как актива?",
            options: ["Гарантированная доходность", "Высокая волатильность — цена может резко падать", "Защита АСВ как у вклада"],
            correctIndex: 1
        ),
        RiskTestQuestion(
            id: 2,
            prompt: "Застрахованы ли криптоактивы государством?",
            options: ["Да, как банковский вклад до 1,4 млн ₽", "Нет, страхования вкладов на них не распространяется", "Да, оператором биржи"],
            correctIndex: 1
        ),
        RiskTestQuestion(
            id: 3,
            prompt: "Сколько средств разумно вкладывать в крипту?",
            options: ["Все накопления", "Кредитные деньги", "Только сумму, потерю которой вы готовы пережить"],
            correctIndex: 2
        ),
        RiskTestQuestion(
            id: 4,
            prompt: "Какой годовой лимит у неквалифицированного инвестора?",
            options: ["300 000 ₽ через посредника", "Без лимита", "1 000 000 ₽"],
            correctIndex: 0
        ),
    ]
}
