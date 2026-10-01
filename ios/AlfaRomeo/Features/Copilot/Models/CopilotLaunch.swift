import Foundation

/// How the copilot is opened — the initial mode plus an optional pre-seeded question and context line.
/// Used by the floating button (standard), the Chats channel (§9.5), and History operations (§10.7).
/// The seeded prompt is placed in the composer; the user still taps send — the human stays in control.
struct CopilotLaunch: Hashable, Sendable {
    var mode: CopilotMode
    var seededPrompt: String?
    /// Shown as the assistant's opening line, framing the context.
    var contextNote: String?

    init(mode: CopilotMode = .support, seededPrompt: String? = nil, contextNote: String? = nil) {
        self.mode = mode
        self.seededPrompt = seededPrompt
        self.contextNote = contextNote
    }

    /// Default support channel (floating button / Chats tab).
    static let standard = CopilotLaunch()

    /// AI-поиск с дашборда (§9.1). The insight bar opens the copilot as the search-and-do surface —
    /// no pre-seeded prompt, the human types the query; the context line frames what it can do.
    static let search = CopilotLaunch(
        mode: .support,
        contextNote: "Поиск по приложению и помощник в одном. Спросите, например: «сколько ушло на кафе в мае», «открыть вклад», «заморозить карту». Найду ответ или подготовлю действие."
    )

    /// «Чат с банком» (§9.5) — the primary reference channel.
    static let bankChat = CopilotLaunch(
        mode: .support,
        contextNote: "Чат с банком. Отвечаю по счетам, картам, продуктам и тарифам. Если нужен живой сотрудник, переключу на оператора в один тап."
    )

    /// «Чат с оператором» (§9.5) — support with an explicit human-escalation path (no live operator;
    /// the escalation is offered in text, §10.9 «человеку в один тап»).
    static let operatorChat = CopilotLaunch(
        mode: .support,
        seededPrompt: "Нужна помощь оператора.",
        contextNote: "Сначала помогу я, так быстрее. В любой момент эскалирую на живого оператора: напишите «оператор» и я переведу диалог на человека."
    )

    /// Open the copilot pre-seeded with a question about a specific operation (§10.7).
    static func operation(id: String, title: String, amount: String) -> CopilotLaunch {
        CopilotLaunch(
            mode: .support,
            seededPrompt: "Объясни операцию «\(title)» на \(amount).",
            contextNote: "Вопрос по операции \(id). Спросите что угодно, например, что это за списание или как его оспорить."
        )
    }

    /// Open the copilot after a declined operation, ready to help (§10.9 контекстные точки «на отказе»).
    static func declined(reason: String) -> CopilotLaunch {
        CopilotLaunch(
            mode: .support,
            seededPrompt: "Почему операция отклонена и что делать?",
            contextNote: "Вижу отказ по операции: \(reason). Подскажу, в чём причина и как продолжить."
        )
    }
}
