import Foundation

// Mirror of /shared/schema/card.schema.json — keep in sync until codegen (Phase 0.3).

enum CardType: String, Codable, CaseIterable, Sendable {
    case virtual, plastic, crypto, disposable
}

enum CardState: String, Codable, CaseIterable, Sendable {
    case active, frozen, issuing, shipping, expired, burned
}

/// A payment card. The PAN token never leaves the server — clients only see `last4` (§6.4, §11.8).
struct Card: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let accountId: String
    let profileId: String
    let type: CardType
    let last4: String
    let state: CardState
    var designId: String?
    let isDefault: Bool
    var assetLink: String?
}
