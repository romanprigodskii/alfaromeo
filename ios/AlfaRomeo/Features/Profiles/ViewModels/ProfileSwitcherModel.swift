import Observation

/// Loads each profile's tier (for the badge) and performs profile switching with the optional
/// business biometric gate (§5.2).
@MainActor
@Observable
final class ProfileSwitcherModel {
    var tiers: [String: SubscriptionTier] = [:]
    var switchingId: String?
    var error: String?

    /// Load the tier of every listed profile via the API (for the row badges).
    func loadTiers(api: any APIClient, profiles: [Profile]) async {
        var map: [String: SubscriptionTier] = [:]
        for profile in profiles {
            if let subscription = try? await api.subscription(profileId: profile.id) {
                map[profile.id] = subscription.tier
            }
        }
        tiers = map
    }

    /// Switch to `profile`. Switching into a business profile may require a biometric re-unlock
    /// (§5.2, toggle in settings). Returns true when the switch happened.
    func switchTo(_ profile: Profile, session: AppSession) async -> Bool {
        error = nil
        guard switchingId == nil else { return false }            // in-flight guard (no double prompt)
        guard profile.id != session.activeProfile?.id else { return true }

        if profile.type == .business && session.requireBiometricForBusinessSwitch {
            switchingId = profile.id
            let unlocked = await BiometricAuthenticator.authenticate(
                reason: "Вход в бизнес-профиль «\(profile.displayName ?? "Бизнес")»"
            )
            switchingId = nil
            guard unlocked else {
                error = "Не удалось подтвердить вход в бизнес-профиль."
                return false
            }
        }

        session.switchProfile(profile)
        return true
    }
}
