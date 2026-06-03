import Foundation

// Mirror of /shared/schema/transaction.schema.json — keep in sync until codegen (Phase 0.3).

enum TransactionKind: String, Codable, CaseIterable, Sendable {
    case transfer, payment, convert, trade, payout, acquire
}

enum TransactionStatus: String, Codable, CaseIterable, Sendable {
    case pending, processing, completed, failed, declined
}

/// A money movement scoped to a ``Profile``.
struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let kind: TransactionKind
    let status: TransactionStatus
    let amount: Double
    let currency: String
    var counterparty: String?
    var fee: Double?
    var fxRate: Double?
    let createdAt: String
}
