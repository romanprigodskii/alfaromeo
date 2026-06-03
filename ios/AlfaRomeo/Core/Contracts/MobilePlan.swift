import Foundation

// Mirror of /shared (MobilePlan, §11.3, §7) — keep in sync until codegen (Phase 0.3).

/// Ромео Mobile (MVNO) plan for a profile — mock operator (§7.3).
struct MobilePlan: Codable, Identifiable, Hashable, Sendable {
    let profileId: String
    let msisdn: String        // phone number
    let esimId: String
    let tariff: String        // S / M / Unlimited, tied to tier (§7.1)
    let dataGb: Double
    let minutes: Int
    let usedGb: Double
    let usedMin: Int
    let roaming: Bool

    var id: String { esimId }
}
