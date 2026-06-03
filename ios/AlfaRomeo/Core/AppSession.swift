import Observation

/// Global session state: authentication + the active profile.
///
/// The app theme is derived from `activeProfile?.type` (§5.2). `AppSession` is the single
/// `@Observable` source of truth, injected via the SwiftUI environment (DI pin).
@MainActor
@Observable
final class AppSession {
    enum AuthState: Equatable {
        case splash            // booting / deciding initial route
        case unauthenticated   // pre-auth flow (onboarding / login / register)
        case authenticated     // signed in
    }

    var authState: AuthState = .splash
    var currentUser: User?
    var activeProfile: Profile?
    var profiles: [Profile] = []

    /// True once the user has authenticated at least once this install. Logout keeps it true so the
    /// pre-auth flow starts at login (Face ID), not onboarding.
    var isReturningUser = false

    /// PIN chosen during registration (demo only — never persisted/secured here).
    var demoPIN: String?

    /// Setting (§5.2): require a biometric re-unlock when switching into a business profile.
    var requireBiometricForBusinessSwitch = false

    /// Live tier upgrades per profile (§4). The screen writes here; entitlements derive from it,
    /// falling back to the profile's API subscription when there's no override.
    var tierOverrides: [String: SubscriptionTier] = [:]

    init() {}

    /// Whether the current context is the business mode — drives navigation + theme (§8, §9.9).
    var isBusinessMode: Bool { activeProfile?.type == .business }

    /// Initials for the navbar avatar, derived from the active profile's display name.
    var avatarInitials: String {
        if let name = activeProfile?.displayName?.trimmingCharacters(in: .whitespaces),
           let first = name.first {
            return String(first).uppercased()
        }
        return "АР"
    }

    // MARK: - Auth transitions

    /// Enter the authenticated shell with a user + active profile (called by the pre-auth flow).
    func completeAuthentication(user: User, profile: Profile, profiles: [Profile]? = nil) {
        self.currentUser = user
        self.profiles = profiles ?? [profile]
        self.activeProfile = profile
        self.isReturningUser = true
        self.authState = .authenticated
    }

    /// Return to the pre-auth flow. Keeps `isReturningUser`/`demoPIN` so login (Face ID/PIN) works.
    func signOut() {
        self.activeProfile = nil
        self.profiles = []
        self.tierOverrides = [:]
        self.authState = .unauthenticated
    }

    // MARK: - Profiles (§5)

    /// Switch the active profile → re-themes, swaps the tab bar, and re-scopes data (`profileId`).
    func switchProfile(_ profile: Profile) {
        activeProfile = profile
    }

    /// Add a new profile under the same KYC and switch to it (§5.2 "+ Добавить профиль").
    func addProfile(_ profile: Profile) {
        if !profiles.contains(where: { $0.id == profile.id }) {
            profiles.append(profile)
        }
        switchProfile(profile)
    }

    // MARK: - Tiers (§4)

    /// Effective tier for a profile: a live override if set, else the API/default `fallback`.
    func currentTier(for profileId: String, fallback: SubscriptionTier) -> SubscriptionTier {
        tierOverrides[profileId] ?? fallback
    }

    /// Mock upgrade/downgrade — activates a tier immediately (§4.3). Entitlements update live.
    func setTier(_ tier: SubscriptionTier, for profileId: String) {
        tierOverrides[profileId] = tier
    }

    // MARK: - Mock seed (used by previews)

    /// A session pre-seeded as signed in with one personal profile.
    static func mockAuthenticated() -> AppSession {
        let session = AppSession()
        session.completeAuthentication(
            user: MockData.user,
            profile: MockData.profiles.first { $0.type == .personal } ?? MockData.profiles[0],
            profiles: MockData.profiles
        )
        return session
    }

    // MARK: - DEBUG

    /// DEBUG ONLY: swap the active profile's type to preview tab-bar + theme switching.
    func debugSetActiveProfileType(_ type: ProfileType) {
        guard let current = activeProfile else { return }
        let updated = Profile(
            id: current.id,
            userId: current.userId,
            type: type,
            displayName: type == .business ? "Бизнес" : "Личный",
            theme: nil,
            createdAt: current.createdAt
        )
        activeProfile = updated
        if let index = profiles.firstIndex(where: { $0.id == current.id }) {
            profiles[index] = updated
        } else {
            profiles = [updated]
        }
    }
}
