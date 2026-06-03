import Foundation

/// A single message in the copilot conversation (§10.9). Assistant turns stream token-by-token —
/// `isStreaming` drives the typing indicator. An action draft (agent mode) or a result receipt attaches
/// its own payload and is rendered as a card / status row rather than plain text.
struct CopilotMessage: Identifiable, Hashable, Sendable {
    enum Role: Hashable, Sendable { case user, assistant }

    let id: UUID
    var role: Role
    var text: String
    var isStreaming: Bool
    /// A proposed financial action (agent mode). Rendered as a confirm card — never executed silently.
    var draft: AIToolDraft?
    /// Receipt shown after a confirmed action resolves.
    var result: CopilotActionReceipt?
    /// True when the turn handed off to a human operator (§11.7 escalation).
    var escalated: Bool

    init(id: UUID = UUID(), role: Role, text: String = "", isStreaming: Bool = false,
         draft: AIToolDraft? = nil, result: CopilotActionReceipt? = nil, escalated: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
        self.draft = draft
        self.result = result
        self.escalated = escalated
    }
}

/// Compact receipt posted into the chat after an agent action executes (or is declined).
struct CopilotActionReceipt: Hashable, Sendable {
    enum Outcome: Hashable, Sendable { case executed, declined }
    let outcome: Outcome
    let message: String
}
