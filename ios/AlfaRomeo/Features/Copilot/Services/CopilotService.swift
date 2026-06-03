import Foundation
import Observation

/// The copilot's transport (§10.9 / §11.7). The app injects ``MockAPIClient`` app-wide, so — exactly like
/// ``LivePriceService`` for prices — this reaches the AI backend DIRECTLY: SSE over `POST /ai/chat` and
/// REST `POST /ai/confirm-action`. It exposes the live + mock ``AIStreamClient``s so callers can try live
/// and fall back to the deterministic mock when the backend is unreachable, and tracks `isLive` for the
/// "online / offline-demo" badge. Shared singleton.
@MainActor
@Observable
final class CopilotService {
    static let shared = CopilotService()

    /// True once a live backend turn has streamed; false → running on the offline mock fallback.
    private(set) var isLive = false

    let live = AIStreamClient(mode: .live)
    let mock = AIStreamClient(mode: .mock)

    private init() {}

    func noteLive() { isLive = true }
    func noteOffline() { isLive = false }

    /// Confirm a biometric-approved draft. Tries live; falls back to a local simulation if the backend is
    /// unreachable (confirm-action is a simulation server-side too, §11.7), so the demo always completes.
    func confirmAction(draft: AIToolDraft, profileId: String) async -> AIConfirmResult {
        do {
            let result = try await live.confirmAction(draft: draft, profileId: profileId)
            isLive = true
            return result
        } catch {
            isLive = false
            if let simulated = try? await mock.confirmAction(draft: draft, profileId: profileId) {
                return simulated
            }
            return AIConfirmResult(status: "rejected", tool: draft.tool,
                                   message: "Не удалось выполнить действие.",
                                   reason: "Сервис временно недоступен.", result: nil)
        }
    }
}
