import Foundation

/// Copilot operating mode (§10.9). `support` = FAQ / operations + escalation; `coach` = proactive
/// advice; `agent` = tool-use that PROPOSES financial actions (drafts only — always confirm + Face ID).
/// `rawValue` is the exact wire value for `POST /ai/chat`.
enum CopilotMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case support
    case coach
    case agent

    var id: String { rawValue }
    var wire: String { rawValue }

    var title: String {
        switch self {
        case .support: return "Поддержка"
        case .coach:   return "Финкоуч"
        case .agent:   return "Агент"
        }
    }

    var icon: String {
        switch self {
        case .support: return "bubble.left.and.text.bubble.right.fill"
        case .coach:   return "chart.line.uptrend.xyaxis"
        case .agent:   return "wand.and.stars"
        }
    }

    /// One-line description of what this mode does — shown under the picker.
    var hint: String {
        switch self {
        case .support: return "Отвечаю по счетам, картам, продуктам и тарифам. Позову оператора, если нужно."
        case .coach:   return "Подскажу, где оптимизировать траты и куда отложить."
        case .agent:   return "Подготовлю перевод, вклад или заморозку карты — выполните тапом и Face ID."
        }
    }
}
