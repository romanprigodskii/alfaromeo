import Foundation
import Observation

/// «Заплатить поставщику» (§8.3) with the multi-step signature gate (§11.8).
///
/// Walks счёт/реквизиты → проверка → подтверждение → статус. Branches on the signing policy:
/// - amount ≤ порога → a single initiator biometric executes the payment (simulation).
/// - amount > порога → the initiator biometric is the **first** of a 2-of-N подпись; the payment is
///   submitted to ``TeamStore`` and lands in «на подпись» for a second signer (владелец / бухгалтер).
///
/// Mirrors ``TransferFlowModel`` (form → confirm → biometric → status); execution and approval state
/// live in ``TeamStore``, the single source of truth.
@MainActor
@Observable
final class SupplierPaymentModel {
    enum Step: Hashable { case details, review, status }
    enum RecipientMode: String, CaseIterable, Identifiable {
        case counterparty, requisites
        var id: String { rawValue }
        var label: String { self == .counterparty ? "Контрагент" : "Реквизиты" }
    }
    /// The terminal state shown on the status step.
    enum Result: Equatable {
        case executed(OperationOutcome)   // ≤ порога — straight-through (success / declined)
        case routedForSignature           // > порога — sent to 2-of-N
    }

    // Input
    var mode: RecipientMode = .counterparty
    var selectedCounterpartyId: String?
    var freeName = ""
    var freeInn = ""
    var freeAccount = ""
    var amountText = ""
    var purpose = ""

    // Flow
    var step: Step = .details
    var authorizing = false
    var result: Result?
    /// The approval created on the 2-of-N path — drives the «отправлено на подпись» status card.
    var submitted: ApprovalItem?

    // Context
    private(set) var counterparties: [Counterparty] = []
    private(set) var sourceTitle = "Расчётный счёт"
    private(set) var sourceBalance: Double = 0
    private var initiatorId = "u_demo"
    private var initiatorName = "Алексей Орлов"

    private let store = TeamStore.shared

    func load(api: any APIClient, session: AppSession) async {
        let profileId = session.activeProfile?.id ?? ""
        initiatorId = store.currentMember?.id ?? session.currentUser?.id ?? "u_demo"
        initiatorName = store.currentMember?.name ?? "Инициатор"
        counterparties = store.counterparties
        if let accounts = try? await api.accounts(profileId: profileId),
           let acc = accounts.first(where: { $0.isRubLike }) ?? accounts.first {
            sourceTitle = "\(acc.displayTitle) ·· \(acc.id.suffix(4))"
            sourceBalance = acc.balance
        }
    }

    // MARK: Derived

    var amount: Double { Self.parse(amountText) }
    var threshold: Double { store.policy.thresholdRub }
    var requiresMultiSignature: Bool { store.requiresMultiSignature(amount: amount) }
    var insufficientFunds: Bool { amount > sourceBalance && sourceBalance > 0 }

    var selectedCounterparty: Counterparty? {
        counterparties.first { $0.id == selectedCounterpartyId }
    }

    var supplierName: String {
        switch mode {
        case .counterparty: return selectedCounterparty?.name ?? "Контрагент"
        case .requisites:   return freeName.isEmpty ? "Получатель" : freeName
        }
    }
    var supplierDetail: String {
        switch mode {
        case .counterparty:
            guard let cp = selectedCounterparty else { return "Выберите контрагента" }
            return "ИНН \(cp.inn)\(cp.account.map { " · \($0)" } ?? "")"
        case .requisites:
            let inn = freeInn.isEmpty ? "" : "ИНН \(freeInn)"
            let acc = freeAccount.isEmpty ? "" : " · \(masked(freeAccount))"
            return inn.isEmpty && acc.isEmpty ? "Введите реквизиты" : inn + acc
        }
    }

    var recipientReady: Bool {
        switch mode {
        case .counterparty: return selectedCounterparty != nil
        case .requisites:   return !freeName.trimmingCharacters(in: .whitespaces).isEmpty
                                && freeAccount.filter(\.isNumber).count >= 8
        }
    }
    var canProceedDetails: Bool { recipientReady && amount > 0 }

    /// The next teammate awaited on the 2-of-N path (for the review banner copy).
    var nextSignerName: String? {
        store.eligibleSigners.first { $0.id != initiatorId }?.name
    }

    // MARK: Steps

    func goToReview() { if canProceedDetails { step = .review } }
    func backToDetails() { step = .details }

    /// Confirm. One biometric prompt — it executes (≤ порога) or places the first signature (> порога).
    func authorize() async {
        authorizing = true
        let reason = requiresMultiSignature
            ? "Подписать платёж поставщику \(Self.rub(amount))"
            : "Оплатить поставщику \(Self.rub(amount))"
        let ok = await BiometricAuthenticator.authenticate(reason: reason)
        authorizing = false
        guard ok else { result = .executed(.declined(.canceled)); step = .status; return }

        if requiresMultiSignature {
            // Initiator's signature = first of 2-of-N → submit for a second signer.
            let draft = makeDraft()
            submitted = store.submitForSignature(draft: draft)
            result = .routedForSignature
            step = .status
        } else {
            result = .executed(.processing)
            step = .status
            try? await Task.sleep(for: .seconds(1.2))
            result = .executed(insufficientFunds ? .declined(.insufficientFunds) : .success)
        }
    }

    func retry() {
        guard case .executed(let outcome) = result, case .declined = outcome else { return }
        result = nil
        step = .review
    }

    private func makeDraft() -> SupplierDraft {
        seqTick += 1
        return SupplierDraft(
            id: "op_\(initiatorId)_\(seqTick)",
            supplierName: supplierName,
            supplierDetail: supplierDetail,
            amount: amount,
            purpose: purpose.isEmpty ? "Оплата поставщику" : purpose,
            sourceTitle: sourceTitle,
            initiatorUserId: initiatorId,
            initiatorName: initiatorName,
            createdAt: Date(timeIntervalSince1970: 2_064_700_800)
        )
    }
    private var seqTick = 0

    // MARK: Helpers

    private func masked(_ account: String) -> String {
        let digits = account.filter(\.isNumber)
        guard digits.count > 4 else { return account }
        return "····\(digits.suffix(4))"
    }

    static func parse(_ s: String) -> Double {
        let cleaned = s
            .replacingOccurrences(of: "\u{2009}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned.filter { $0.isNumber || $0 == "." }) ?? 0
    }
    static func rub(_ value: Double) -> String {
        (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))") + " ₽"
    }
    static let formatter: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"; f.maximumFractionDigits = 0
        return f
    }()
}
