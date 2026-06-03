import Foundation

/// Per-day AI request quota (§0.6 / §10.9). Base / Бизнес-Старт have a daily cap
/// (`Entitlements.aiRequestsPerDay`); Pro+ are unlimited (`nil`). Counts user-initiated turns, resets at
/// local midnight, and is persisted per profile (a relaunch doesn't reset the cap). Demo-grade — backed
/// by `UserDefaults`. Shared singleton, main-actor confined (mirrors the other feature stores).
@MainActor
final class CopilotQuota {
    static let shared = CopilotQuota()

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private func key(_ profileId: String) -> String {
        "ai.quota.\(profileId).\(Self.dayFormatter.string(from: Date()))"
    }

    /// Requests already used today for this profile.
    func used(profileId: String) -> Int { defaults.integer(forKey: key(profileId)) }

    /// Remaining requests today, or `nil` when the tier is unlimited.
    func remaining(limit: Int?, profileId: String) -> Int? {
        guard let limit else { return nil }
        return max(0, limit - used(profileId: profileId))
    }

    /// May the profile send another request right now? Unlimited tiers (`limit == nil`) always can.
    func canSend(limit: Int?, profileId: String) -> Bool {
        guard let limit else { return true }
        return used(profileId: profileId) < limit
    }

    /// Record one consumed request.
    func record(profileId: String) {
        defaults.set(used(profileId: profileId) + 1, forKey: key(profileId))
    }

    #if DEBUG
    /// Clear today's count (debug helper for exercising the limit repeatedly).
    func reset(profileId: String) { defaults.removeObject(forKey: key(profileId)) }
    #endif
}
