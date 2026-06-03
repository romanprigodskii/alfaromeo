import Foundation
import Observation

/// The copilot conversation (§10.9): holds the transcript, sends turns through ``CopilotService``
/// (live SSE with a transparent mock fallback), folds the stream into a streaming assistant bubble,
/// intercepts action drafts (agent mode), surfaces escalation, and enforces the Base daily request limit
/// (§0.6). One instance per chat surface.
@MainActor
@Observable
final class CopilotChatModel {
    var messages: [CopilotMessage] = []
    var input: String = ""
    var mode: CopilotMode
    var isStreaming = false
    /// Set when the Base daily quota is exhausted — the view shows the soft upsell instead of sending.
    var quotaReached = false

    let profileId: String
    let tier: Tier
    let aiLimit: Int?          // nil = unlimited (Pro+)

    private let service: CopilotService
    private let quota: CopilotQuota
    private var streamTask: Task<Void, Never>?

    init(profileId: String, tier: Tier, mode: CopilotMode, aiLimit: Int?) {
        self.profileId = profileId
        self.tier = tier
        self.mode = mode
        self.aiLimit = aiLimit
        self.service = .shared
        self.quota = .shared
    }

    var isLive: Bool { service.isLive }
    var remaining: Int? { quota.remaining(limit: aiLimit, profileId: profileId) }

    /// Seed the opening assistant note + optional pre-filled composer text (context entry points).
    func prepare(launch: CopilotLaunch) {
        guard messages.isEmpty else { return }
        let opening = launch.contextNote ?? "Здравствуйте! Я Claude-копилот Альфа-Ромео. \(mode.hint)"
        messages.append(CopilotMessage(role: .assistant, text: opening))
        if let seed = launch.seededPrompt { input = seed }
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        // Base daily limit (§0.6). Pro+ → aiLimit == nil → never blocked.
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

    /// One-tap escalation to a human operator (§11.7 «человеку» в тап). Doesn't consume the daily quota.
    func escalate() {
        guard !isStreaming else { return }
        input = ""
        messages.append(CopilotMessage(role: .user, text: "Подключите, пожалуйста, оператора."))
        startStream()
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    /// Post the action result into the chat once the confirm sheet closes.
    func appendReceipt(_ receipt: CopilotActionReceipt) {
        messages.append(CopilotMessage(role: .assistant, result: receipt))
    }

    // MARK: - Streaming

    /// Conversation history for the API — plain user/assistant text only (drafts/receipts excluded).
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
        let currentMode = mode
        messages.append(CopilotMessage(role: .assistant, isStreaming: true))
        let index = messages.count - 1
        isStreaming = true

        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in self.service.live.stream(messages: history, mode: currentMode.wire, profileId: self.profileId) {
                    if Task.isCancelled { break }
                    self.service.noteLive()
                    self.handle(event, at: index)
                }
            } catch {
                // Fall back to the offline mock ONLY when nothing has rendered yet — covers a connection
                // that failed before the first byte (and an empty response). If the live stream had already
                // produced text/a draft and then dropped, keep the partial answer: restarting with the mock
                // would append a second, duplicate reply onto it. Cancellation (view torn down) never falls back.
                if !Task.isCancelled && self.nothingRendered(at: index) {
                    self.service.noteOffline()
                    do {
                        for try await event in self.service.mock.stream(messages: history, mode: currentMode.wire, profileId: self.profileId) {
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

    /// Has the assistant bubble shown nothing yet (no text, no action draft)? Drives the offline fallback.
    private func nothingRendered(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        return messages[index].text.isEmpty && messages[index].draft == nil
    }

    private func failIfEmpty(at index: Int) {
        guard messages.indices.contains(index), messages[index].text.isEmpty, messages[index].draft == nil else { return }
        messages[index].text = "Не удалось связаться с ассистентом. Попробуйте позже или позовите оператора кнопкой ниже."
    }

    private func finish(at index: Int) {
        if messages.indices.contains(index) { messages[index].isStreaming = false }
        isStreaming = false
    }
}
