import Foundation

// Mirror of /shared/schema/membership.schema.json — keep in sync until codegen (Phase 0.3).

enum MembershipRole: String, Codable, CaseIterable, Sendable {
    case owner, admin, accountant, manager, member
}

/// Role + permissions of a ``User`` within a ``Profile`` (team / multi-step signing, §5.3, §11.8).
struct Membership: Codable, Hashable, Sendable {
    let userId: String
    let profileId: String
    let role: MembershipRole
    let permissions: [String]
}
