import Foundation

/// The signing policy for business payments (§8.2 / §11.8): payments at or below `thresholdRub`
/// execute on a single biometric; anything above routes to a **multi-step 2-of-N подпись** by
/// signers (владелец / бухгалтер).
struct SigningPolicy: Hashable, Sendable {
    var thresholdRub: Double
    var requiredSigners: Int

    static let standard = SigningPolicy(thresholdRub: 500_000, requiredSigners: 2)

    func requiresMultiSignature(amount: Double) -> Bool { amount > thresholdRub }
}

/// The human-readable payment behind an ``ApprovalRequest`` (the contract carries only ids + the
/// `signedBy` list). Paired by `opId` in ``TeamStore`` so the «на подпись» list and the approval
/// detail can render «кому / сколько / откуда» without putting display strings in the contract.
struct SupplierDraft: Identifiable, Hashable, Sendable {
    let id: String                 // == ApprovalRequest.opId
    var supplierName: String
    var supplierDetail: String     // ИНН · счёт (masked)
    var amount: Double
    var purpose: String
    var sourceTitle: String        // списание со счёта
    var initiatorUserId: String
    var initiatorName: String
    var createdAt: Date
}

/// A resolved signature slot for the 2-of-N progress UI: which teammate signed (or is awaited) and
/// when. Built by ``TeamStore`` from an ``ApprovalRequest.signedBy`` + the team roster.
struct SignatureSlot: Identifiable, Hashable, Sendable {
    enum Phase: Hashable, Sendable { case signed, awaiting, optional }
    let id: String                 // userId, or "awaiting-i" for an unfilled slot
    var name: String
    var initials: String
    var roleLabel: String
    var phase: Phase
}

/// A pending approval joined with its draft + resolved signature slots — the view-model the
/// approvals list and detail consume. Wraps the contract ``ApprovalRequest`` (source of truth for
/// `required` / `signedBy` / `status`).
struct ApprovalItem: Identifiable, Hashable, Sendable {
    let request: ApprovalRequest
    let draft: SupplierDraft
    let slots: [SignatureSlot]

    var id: String { request.id }
    var signedCount: Int { request.signedBy.count }
    var required: Int { request.required }
    var isComplete: Bool { request.status == .signed }
    var isRejected: Bool { request.status == .rejected }
    var progress: Double { required > 0 ? min(Double(signedCount) / Double(required), 1) : 0 }

    /// Short progress label, e.g. «1 из 2 подписей».
    var progressLabel: String { "\(signedCount) из \(required) подписей" }
}

/// Why a signer could not add their signature (single-device demo edge cases).
enum SignError: Error, Equatable, Sendable {
    case biometricFailed
    case alreadySigned
    case notEligible
    case noEligibleSigner

    var message: String {
        switch self {
        case .biometricFailed: return "Подтверждение не пройдено. Подпись не добавлена."
        case .alreadySigned:   return "Этот подписант уже поставил подпись."
        case .notEligible:     return "У роли нет права подписи (нужен владелец или бухгалтер)."
        case .noEligibleSigner: return "Нет доступного второго подписанта с правом подписи."
        }
    }
}
