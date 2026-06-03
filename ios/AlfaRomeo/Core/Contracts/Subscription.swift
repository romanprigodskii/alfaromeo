import Foundation

// Mirror of /shared/schema/subscription.schema.json — keep in sync until codegen (Phase 0.3).

enum SubscriptionTier: String, Codable, CaseIterable, Sendable {
    case base, pro, infinite
    case bizStart = "biz_start"
    case bizPro = "biz_pro"
    case bizCorp = "biz_corp"
}

enum SubscriptionStatus: String, Codable, CaseIterable, Sendable {
    case active, trialing, canceled
    case pastDue = "past_due"
}

/// Membership tier for a ``Profile`` — a set of feature-flags + limits, not separate screens (§4).
struct Subscription: Codable, Hashable, Sendable {
    let profileId: String
    let tier: SubscriptionTier
    let status: SubscriptionStatus
    var renewsAt: String?
    var price: Double?
}
