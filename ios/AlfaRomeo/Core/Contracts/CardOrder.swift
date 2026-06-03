import Foundation

// Mirror of /shared (CardOrder, §11.3) — keep in sync until codegen (Phase 0.3).

/// Physical card fulfilment status (mock logistics, §6.2/§6.4).
enum PhysicalCardStatus: String, Codable, CaseIterable, Sendable {
    case none, ordered, printing, shipping, delivered
}

/// A card order: virtual issues instantly; the optional physical card ships with mock tracking.
struct CardOrder: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let cardType: CardType
    var designId: String?
    var virtualIssuedAt: String?
    let physicalStatus: PhysicalCardStatus
    var tracking: String?
    var address: String?
}
