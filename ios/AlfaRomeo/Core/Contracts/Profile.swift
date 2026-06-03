import Foundation

// Mirror of /shared/schema/profile.schema.json — keep in sync until codegen (Phase 0.3).

enum ProfileType: String, Codable, CaseIterable, Sendable {
    case personal, business, joint, child
}

/// An isolated context under one ``User``. The app theme is derived from `type` (§5.2).
struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let type: ProfileType
    var displayName: String?
    var theme: String?
    let createdAt: String
}
