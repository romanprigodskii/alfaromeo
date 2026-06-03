import Foundation

// Mirror of /shared/schema/account.schema.json — keep in sync until codegen (Phase 0.3).

enum AccountType: String, Codable, CaseIterable, Sendable {
    case current, savings, crypto
    case digitalRuble = "digital_ruble"
}

/// A balance container scoped to a ``Profile``.
struct Account: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let type: AccountType
    let currency: String
    let balance: Double
}
