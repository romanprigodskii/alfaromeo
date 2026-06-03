import Foundation
import Observation

/// Drives a single agent action draft from confirm card → Face ID → `POST /ai/confirm-action` →
/// animated status (§11.7). Mirrors ``TransferFlowModel``: the AI proposes, the USER executes with a tap
/// + real biometrics. Blocked drafts (guardrails) never reach biometrics.
@MainActor
@Observable
final class CopilotActionModel {
    enum Phase: Hashable {
        case confirm        // showing the draft, awaiting the user
        case authorizing    // Face ID prompt up
        case processing     // confirm-action in flight
        case done(AIConfirmResult)
    }

    let draft: AIToolDraft
    let profileId: String
    private let service: CopilotService

    var phase: Phase = .confirm

    init(draft: AIToolDraft, profileId: String) {
        self.draft = draft
        self.profileId = profileId
        self.service = .shared
    }

    var biometryLabel: String { BiometricAuthenticator.available().label }

    /// Confirm → biometrics → execute. A cancelled / failed biometric ends in a declined receipt; the AI
    /// never moves money on its own.
    func confirm() async {
        guard !draft.blocked else { return }
        phase = .authorizing
        let ok = await BiometricAuthenticator.authenticate(reason: draft.summary)
        guard ok else {
            phase = .done(AIConfirmResult(status: "rejected", tool: draft.tool,
                                          message: "Подтверждение не пройдено. Действие не выполнено.",
                                          reason: "biometric", result: nil))
            return
        }
        phase = .processing
        let result = await service.confirmAction(draft: draft, profileId: profileId)
        phase = .done(result)
    }
}
