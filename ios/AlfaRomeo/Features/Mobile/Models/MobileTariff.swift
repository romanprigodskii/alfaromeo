import Foundation

/// A Ромео Mobile tariff (§7.1). The tariff is **derived from the membership tier**, not chosen
/// freely: Base → пакет S, Pro → пакет M (+роуминг), Infinite → безлимит. So `requiredTier` is the
/// canonical personal tier that unlocks this package, and the hub always shows the tariff matching
/// the active profile's effective tier (§4 «feature flags + лимиты», not separate screens).
struct MobileTariff: Identifiable, Hashable, Sendable {
    let package: Entitlements.MobilePackage
    let name: String
    let dataGb: Double?      // nil = безлимит
    let minutes: Int?        // nil = безлимит
    let roamingIncluded: Bool
    let cashbackGbPerMonth: Double
    let requiredTier: Tier

    var id: String { package.rawValue }
    var isUnlimited: Bool { dataGb == nil }

    var dataLabel: String { dataGb.map { Self.format($0) + " ГБ" } ?? "Безлимит" }
    var minutesLabel: String { minutes.map { "\($0) мин" } ?? "Безлимит" }
    var roamingLabel: String { roamingIncluded ? "Роуминг включён" : "Роуминг по запросу" }

    /// Build a tariff from a tier's mobile package (§7.1).
    static func make(for package: Entitlements.MobilePackage) -> MobileTariff {
        switch package {
        case .s:
            return MobileTariff(package: .s, name: "Пакет S", dataGb: 15, minutes: 300,
                                roamingIncluded: false, cashbackGbPerMonth: 1.0, requiredTier: .base)
        case .m:
            return MobileTariff(package: .m, name: "Пакет M", dataGb: 30, minutes: 600,
                                roamingIncluded: true, cashbackGbPerMonth: 2.5, requiredTier: .pro)
        case .unlimited:
            return MobileTariff(package: .unlimited, name: "Безлимит", dataGb: nil, minutes: nil,
                                roamingIncluded: true, cashbackGbPerMonth: 5.0, requiredTier: .infinite)
        }
    }

    /// The tariff bound to a tier — the tariff↔tier link (§7.1). Works for business tiers too
    /// (their package maps via ``Entitlements``).
    static func make(for tier: Tier) -> MobileTariff {
        make(for: Entitlements.make(for: tier).mobilePackage)
    }

    /// The three personal tariffs, in order, for the chooser (§9.7 Тарифы).
    static let personalCatalog: [MobileTariff] = [
        .make(for: Entitlements.MobilePackage.s),
        .make(for: Entitlements.MobilePackage.m),
        .make(for: Entitlements.MobilePackage.unlimited),
    ]

    static func format(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
