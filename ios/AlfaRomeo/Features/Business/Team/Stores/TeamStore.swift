import Foundation
import Observation

/// Shared, in-memory state for the business «Команда и роли» section (§8.2, §11.8).
///
/// Mirrors the Cards/Mobile module pattern: a `@MainActor @Observable` singleton, held via `@State`
/// in each screen, so a payment submitted for signature in the supplier flow, a signature added in
/// the approval detail, an employee added, or a corp-card frozen all reflect live across the hub and
/// its pushed sub-screens (which have no shared view ancestor — they ride the section `NavigationStack`).
///
/// The backend slice exposes only `business` + `counterparties` for this profile, so the **roster,
/// corp-cards, and approvals are seeded feature-locally** for the demo. The approval state itself is
/// the contract ``ApprovalRequest`` (source of truth for `required` / `signedBy` / `status`); a
/// parallel `drafts` map carries the human-readable payment behind each `opId`. Every mutation is a
/// simulation — no money moves, no PAN materialises (§11.8).
@MainActor
@Observable
final class TeamStore {
    static let shared = TeamStore()

    private(set) var members: [TeamMember] = []
    private(set) var corpCards: [CorporateCard] = []
    /// Contract approval requests — the signing source of truth (§11.8).
    private(set) var approvals: [ApprovalRequest] = []
    /// Display payload behind each approval, keyed by `ApprovalRequest.opId`.
    private(set) var drafts: [String: SupplierDraft] = [:]
    /// Counterparties from the backend slice (supplier picker in the payment flow).
    private(set) var counterparties: [Counterparty] = []

    let policy = SigningPolicy.standard

    private(set) var didLoad = false
    private(set) var loadFailed = false

    private(set) var businessId = ""
    private(set) var currentUserId = ""
    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, currentUserId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        self.businessId = profileId
        self.currentUserId = currentUserId.isEmpty ? "u_demo" : currentUserId
        do {
            // The roster/cards/approvals are seeded locally; counterparties are the one real fetch
            // (best-effort — the flow also accepts free-form requisites).
            let cps = (try? await api.counterparties(businessProfileId: profileId)) ?? []
            counterparties = cps
            seedRoster()
            seedCorpCards()
            seedApprovals()
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId
        }
    }

    // MARK: - Roster

    func member(id: String) -> TeamMember? { members.first { $0.id == id } }
    var currentMember: TeamMember? { members.first { $0.isCurrentUser } ?? members.first }

    /// Teammates allowed to sign a 2-of-N approval (§11.8: владелец / бухгалтер).
    var eligibleSigners: [TeamMember] { members.filter(\.canSign) }

    @discardableResult
    func addMember(name: String, role: MembershipRole, email: String) -> TeamMember {
        seq += 1
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let member = TeamMember(
            id: "m_new_\(seq)",
            name: trimmed.isEmpty ? RoleCatalog.label(role) : trimmed,
            role: role,
            email: email.isEmpty ? "\(role.rawValue)\(seq)@romashka.ru" : email,
            isCurrentUser: false,
            joinedAt: referenceNow
        )
        members.append(member)
        return member
    }

    func changeRole(_ role: MembershipRole, memberId: String) {
        guard let i = members.firstIndex(where: { $0.id == memberId }) else { return }
        members[i].role = role
    }

    func removeMember(memberId: String) {
        members.removeAll { $0.id == memberId && !$0.isCurrentUser }
        corpCards.removeAll { $0.holderUserId == memberId }
    }

    // MARK: - Corp cards

    func cards(forMemberId id: String) -> [CorporateCard] {
        corpCards.filter { $0.holderUserId == id }
    }
    func corpCard(id: String) -> CorporateCard? { corpCards.first { $0.id == id } }

    @discardableResult
    func issueCorpCard(toUserId: String, kind: CorporateCard.Kind, monthlyLimit: Double) -> CorporateCard {
        seq += 1
        let holder = member(id: toUserId)
        let card = CorporateCard(
            id: "cc_\(seq)",
            holderUserId: toUserId,
            holderName: holder?.name ?? "Сотрудник",
            kind: kind,
            last4: String(format: "%04d", 1000 + (seq * 37) % 9000),
            monthlyLimit: monthlyLimit,
            monthlySpent: 0,
            state: .active
        )
        corpCards.append(card)
        return card
    }

    func setCardFrozen(_ frozen: Bool, cardId: String) {
        guard let i = corpCards.firstIndex(where: { $0.id == cardId }) else { return }
        corpCards[i].state = frozen ? .frozen : .active
    }

    func setCardLimit(_ limit: Double, cardId: String) {
        guard let i = corpCards.firstIndex(where: { $0.id == cardId }) else { return }
        corpCards[i].monthlyLimit = max(0, limit)
    }

    // MARK: - Approvals (2-of-N, §11.8)

    func requiresMultiSignature(amount: Double) -> Bool { policy.requiresMultiSignature(amount: amount) }

    var pendingCount: Int { approvals.filter { $0.status == .pending }.count }

    /// All approvals joined with their drafts + resolved signature slots, newest first.
    var allApprovalItems: [ApprovalItem] {
        approvals.compactMap(item(for:))
            .sorted { $0.draft.createdAt > $1.draft.createdAt }
    }
    var pendingApprovalItems: [ApprovalItem] { allApprovalItems.filter { $0.request.status == .pending } }
    func approvalItem(id: String) -> ApprovalItem? {
        approvals.first { $0.id == id }.flatMap(item(for:))
    }

    /// Submit a supplier payment for multi-step signing. The initiator's authorization counts as the
    /// **first** signature, so the request is created already carrying their userId (§8.3).
    @discardableResult
    func submitForSignature(draft: SupplierDraft) -> ApprovalItem? {
        seq += 1
        let request = ApprovalRequest(
            id: "ar_\(seq)",
            businessId: businessId,
            opId: draft.id,
            required: policy.requiredSigners,
            signedBy: [draft.initiatorUserId],
            status: .pending
        )
        drafts[draft.id] = draft
        approvals.insert(request, at: 0)
        return item(for: request)
    }

    /// The next teammate eligible to sign this approval (canSign, not yet signed) — the single-device
    /// demo signs «as» this person so 2-of-N is tangible.
    func nextEligibleSigner(approvalId: String) -> TeamMember? {
        guard let request = approvals.first(where: { $0.id == approvalId }) else { return nil }
        return eligibleSigners.first { !request.signedBy.contains($0.id) }
    }

    /// Add a signature. Caller has already passed biometrics (§11.8: подтверждение биометрией каждым
    /// подписантом). When the required count is reached the approval flips to `.signed` and the
    /// payment is executed (simulation). Returns the updated item or a ``SignError``.
    @discardableResult
    func sign(approvalId: String, asUserId: String) -> Result<ApprovalItem, SignError> {
        guard let i = approvals.firstIndex(where: { $0.id == approvalId }) else { return .failure(.notEligible) }
        let request = approvals[i]
        guard let signer = member(id: asUserId), signer.canSign else { return .failure(.notEligible) }
        guard !request.signedBy.contains(asUserId) else { return .failure(.alreadySigned) }

        let newSignedBy = request.signedBy + [asUserId]
        let complete = newSignedBy.count >= request.required
        let updated = ApprovalRequest(
            id: request.id,
            businessId: request.businessId,
            opId: request.opId,
            required: request.required,
            signedBy: newSignedBy,
            status: complete ? .signed : .pending      // .signed ⇒ fully signed → executed (simulated)
        )
        approvals[i] = updated
        return .success(item(for: updated)!)
    }

    func reject(approvalId: String, byUserId: String) {
        guard let i = approvals.firstIndex(where: { $0.id == approvalId }) else { return }
        let r = approvals[i]
        approvals[i] = ApprovalRequest(id: r.id, businessId: r.businessId, opId: r.opId,
                                       required: r.required, signedBy: r.signedBy, status: .rejected)
    }

    // MARK: - Item assembly

    private func item(for request: ApprovalRequest) -> ApprovalItem? {
        guard let draft = drafts[request.opId] else { return nil }
        return ApprovalItem(request: request, draft: draft, slots: slots(for: request))
    }

    /// Resolve the 2-of-N signature slots: one `.signed` slot per `signedBy` id, then `.awaiting`
    /// slots for the remaining required signatures, named after the next eligible signers.
    private func slots(for request: ApprovalRequest) -> [SignatureSlot] {
        var result: [SignatureSlot] = request.signedBy.map { uid in
            let m = member(id: uid)
            return SignatureSlot(id: uid, name: m?.name ?? "Подписант",
                                 initials: m?.initials ?? "?",
                                 roleLabel: m.map { RoleCatalog.label($0.role) } ?? "—",
                                 phase: .signed)
        }
        guard request.status != .rejected else { return result }
        let remaining = max(0, request.required - request.signedBy.count)
        let waiting = eligibleSigners.filter { !request.signedBy.contains($0.id) }
        for n in 0..<remaining {
            if n < waiting.count {
                let m = waiting[n]
                result.append(SignatureSlot(id: m.id, name: m.name, initials: m.initials,
                                            roleLabel: RoleCatalog.label(m.role), phase: .awaiting))
            } else {
                result.append(SignatureSlot(id: "awaiting-\(n)", name: "Подписант",
                                            initials: "?", roleLabel: "владелец / бухгалтер",
                                            phase: .awaiting))
            }
        }
        return result
    }

    // MARK: - Seeds

    private func seedRoster() {
        members = [
            TeamMember(id: currentUserId, name: "Алексей Орлов", role: .owner,
                       email: "a.orlov@romashka.ru", isCurrentUser: true, joinedAt: date("2035-02-01")),
            TeamMember(id: "m_maria", name: "Мария Кузнецова", role: .accountant,
                       email: "m.kuzn@romashka.ru", isCurrentUser: false, joinedAt: date("2035-02-04")),
            TeamMember(id: "m_oleg", name: "Олег Соколов", role: .manager,
                       email: "o.sokol@romashka.ru", isCurrentUser: false, joinedAt: date("2035-03-10")),
            TeamMember(id: "m_darya", name: "Дарья Лебедева", role: .manager,
                       email: "d.lebed@romashka.ru", isCurrentUser: false, joinedAt: date("2035-04-22")),
        ]
    }

    private func seedCorpCards() {
        corpCards = [
            CorporateCard(id: "cc_seed_1", holderUserId: "m_maria", holderName: "Мария Кузнецова",
                          kind: .virtual, last4: "8021", monthlyLimit: 150_000, monthlySpent: 47_800, state: .active),
            CorporateCard(id: "cc_seed_2", holderUserId: "m_oleg", holderName: "Олег Соколов",
                          kind: .plastic, last4: "1190", monthlyLimit: 80_000, monthlySpent: 61_400, state: .active),
        ]
    }

    private func seedApprovals() {
        let opId = "op_seed_1"
        let draft = SupplierDraft(
            id: opId,
            supplierName: counterparties.first?.name ?? "ООО Поставщик",
            supplierDetail: "ИНН \(counterparties.first?.inn ?? "7709876543") · \(counterparties.first?.account ?? "40702810…001")",
            amount: 740_000,
            purpose: "Оплата по счёту № 1180 от 28.05",
            sourceTitle: "Расчётный счёт ·· 3900",
            initiatorUserId: currentUserId,
            initiatorName: "Алексей Орлов",
            createdAt: date("2035-06-02")
        )
        drafts[opId] = draft
        approvals = [
            ApprovalRequest(id: "ar_seed_1", businessId: businessId, opId: opId,
                            required: policy.requiredSigners, signedBy: [currentUserId], status: .pending),
        ]
    }

    // MARK: - Deterministic dates (Date.now is unavailable in some contexts; fixed demo clock)

    private var referenceNow: Date { Date(timeIntervalSince1970: 2_064_700_800) } // 2035-06-02
    private func date(_ ymd: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: ymd) ?? referenceNow
    }
}
