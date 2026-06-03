import Foundation

// Mirror of /shared/schema/user.schema.json — keep in sync until codegen (Phase 0.3).

enum KycStatus: String, Codable, CaseIterable, Sendable {
    case none, pending, verified, rejected
}

enum InvestorStatus: String, Codable, CaseIterable, Sendable {
    case none, unqualified, qualified
}

/// One human, one KYC. Owns many ``Profile``s.
struct User: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let phone: String
    let kycStatus: KycStatus
    let investorStatus: InvestorStatus
    let createdAt: String
}
