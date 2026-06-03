import Foundation

// Mirror of /shared (Deposit, §11.3) — keep in sync until codegen (Phase 0.3).

/// Ruble deposit vs crypto staking (the "Приумножить" hub, §10.6).
enum DepositKind: String, Codable, CaseIterable, Sendable {
    case ruble, stake
}

/// A savings product: ruble deposit or crypto stake. (`kind` maps spec field `type[ruble|stake]`.)
struct Deposit: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let kind: DepositKind
    var asset: String?      // nil for ruble deposits; the staked asset otherwise
    let principal: Double
    let rateApy: Double      // annual %, e.g. 16.5
    var term: Int?           // months; nil for open-ended stakes
    var lockUntil: String?   // ISO-8601
}
