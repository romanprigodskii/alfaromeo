import Foundation
import Observation

/// The AI-бухгалтер conversation (§8.2). REUSES the Phase-3 AI stack end-to-end — same transport
/// (``CopilotService`` → `POST /ai/chat` SSE with a transparent mock fallback), same message/draft
/// models (``CopilotMessage`` / ``AIToolDraft``), same biometric confirm path (``CopilotActionSheet``).
/// The ONLY differences from ``CopilotChatModel`` are the wire mode (`"business"`, which selects the
/// backend's AI-accountant prompt + the `create_invoice` / `pay_supplier` tools) and a business opening
/// line + quick-prompts. No second AI layer is introduced.
@MainActor
@Observable
final class AIAccountantChatModel {
    var messages: [CopilotMessage] = []
    var input: String = ""
    var isStreaming = false
    /// Set when the Base/Старт daily quota is exhausted — the view shows the soft upsell (§0.6 / §4).
    var quotaReached = false

    let profileId: String
    let tier: Tier
    let aiLimit: Int?          // nil = unlimited (Pro+ / business)

    /// Wire mode for `POST /ai/chat` — the backend AI-бухгалтер (`AIMode = 'business'`, §8.2).
    private let wireMode = "business"

    private let service: CopilotService
    private let quota: CopilotQuota
    private var streamTask: Task<Void, Never>?

    init(profileId: String, tier: Tier, aiLimit: Int?) {
        self.profileId = profileId
        self.tier = tier
        self.aiLimit = aiLimit
        self.service = .shared
        self.quota = .shared
    }

    var isLive: Bool { service.isLive }
    var remaining: Int? { quota.remaining(limit: aiLimit, profileId: profileId) }
    /// Has the user said anything yet? Drives the "scroll-to-chat" affordance under the insight cards.
    var hasConversation: Bool { messages.contains { $0.role == .user } }

    /// Seed the opening assistant note (business framing). Idempotent.
    func prepareOpening() {
        guard messages.isEmpty else { return }
        messages.append(CopilotMessage(role: .assistant, text:
            "Я — AI-бухгалтер «Альфа-Ромео». Вижу ваш денежный поток, налоги и расходы. " +
            "Спросите про прогноз и кассовый разрыв, оптимизацию налога или анализ расходов — " +
            "или поручите выставить счёт / оплатить поставщику. Действия подтвердите биометрией."))
    }

    /// A quick-prompt chip / card CTA: drop a question into the composer and send it (live Claude).
    func quickPrompt(_ text: String) {
        guard !isStreaming else { return }
        input = text
        send()
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        guard quota.canSend(limit: aiLimit, profileId: profileId) else {
            quotaReached = true
            return
        }
        quota.record(profileId: profileId)
        quotaReached = false

        input = ""
        messages.append(CopilotMessage(role: .user, text: text))
        startStream()
    }

    /// One-tap escalation to a human accountant/operator (§11.7). Doesn't consume the daily quota.
    func escalate() {
        guard !isStreaming else { return }
        input = ""
        messages.append(CopilotMessage(role: .user, text: "Подключите, пожалуйста, бухгалтера-человека."))
        startStream()
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    /// Post an action result (invoice issued / supplier paid / declined) into the chat after confirm.
    func appendReceipt(_ receipt: CopilotActionReceipt) {
        messages.append(CopilotMessage(role: .assistant, result: receipt))
    }

    // MARK: - Streaming (identical shape to CopilotChatModel; mode = "business")

    private func wireHistory() -> [AIChatMessage] {
        messages.compactMap { m in
            guard m.draft == nil, m.result == nil else { return nil }
            let content = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            switch m.role {
            case .user:      return AIChatMessage(role: "user", content: content)
            case .assistant: return AIChatMessage(role: "assistant", content: content)
            }
        }
    }

    private func startStream() {
        let history = wireHistory()
        messages.append(CopilotMessage(role: .assistant, isStreaming: true))
        let index = messages.count - 1
        isStreaming = true

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in self.service.live.stream(messages: history, mode: self.wireMode, profileId: self.profileId) {
                    if Task.isCancelled { break }
                    self.service.noteLive()
                    self.handle(event, at: index)
                }
            } catch {
                // Fall back to the offline mock only when nothing has rendered yet (connection failed
                // before the first byte). A partial live answer is kept rather than duplicated.
                if !Task.isCancelled && self.nothingRendered(at: index) {
                    self.service.noteOffline()
                    do {
                        for try await event in self.service.mock.stream(messages: history, mode: self.wireMode, profileId: self.profileId) {
                            if Task.isCancelled { break }
                            self.handle(event, at: index)
                        }
                    } catch {
                        self.failIfEmpty(at: index)
                    }
                }
            }
            self.finish(at: index)
        }
    }

    private func handle(_ event: AIStreamEvent, at index: Int) {
        guard messages.indices.contains(index) else { return }
        switch event {
        case .token(let t):
            messages[index].text += t
        case .toolDraft(let draft):
            messages[index].draft = draft
            if messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[index].text = draft.summary
            }
        case .done(let escalated):
            messages[index].escalated = escalated
        }
    }

    private func nothingRendered(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        return messages[index].text.isEmpty && messages[index].draft == nil
    }

    private func failIfEmpty(at index: Int) {
        guard messages.indices.contains(index), messages[index].text.isEmpty, messages[index].draft == nil else { return }
        messages[index].text = "Не удалось связаться с AI-бухгалтером. Попробуйте позже или позовите специалиста кнопкой ниже."
    }

    private func finish(at index: Int) {
        if messages.indices.contains(index) { messages[index].isStreaming = false }
        isStreaming = false
    }
}
