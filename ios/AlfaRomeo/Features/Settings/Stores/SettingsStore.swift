import SwiftUI
import Observation

/// Feature-local, persisted user settings (§9.8). Mirrors the project's store paradigm: a
/// `@MainActor @Observable` singleton (so views re-render on change) backed by `UserDefaults` (so the
/// choices survive relaunch) — same spirit as `CopilotQuota`/`BenefitsStore`, combined. No backend.
///
/// The theme preference is read at the app root (``RootView``) and the shell sheet, so flipping it
/// re-themes the whole app live. Security/notification toggles are demo-grade switches.
@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Appearance / language
    var themePreference: ThemePreference { didSet { defaults.set(themePreference.rawValue, forKey: K.theme) } }
    var language: AppLanguage            { didSet { defaults.set(language.rawValue, forKey: K.language) } }

    // MARK: Security
    var faceIDUnlock: Bool   { didSet { defaults.set(faceIDUnlock, forKey: K.faceID) } }
    var pinEnabled: Bool     { didSet { defaults.set(pinEnabled, forKey: K.pin) } }
    var passkeysEnabled: Bool { didSet { defaults.set(passkeysEnabled, forKey: K.passkeys) } }
    /// Per-operation confirmation limit (₽). `0` → без лимита.
    var perOperationLimit: Double { didSet { defaults.set(perOperationLimit, forKey: K.opLimit) } }

    // MARK: Notifications
    var notifyPush: Bool         { didSet { defaults.set(notifyPush, forKey: K.nPush) } }
    var notifyTransactions: Bool { didSet { defaults.set(notifyTransactions, forKey: K.nTx) } }
    var notifySecurity: Bool     { didSet { defaults.set(notifySecurity, forKey: K.nSec) } }
    var notifyMarketing: Bool    { didSet { defaults.set(notifyMarketing, forKey: K.nMkt) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Init assignments don't fire `didSet` (Swift rule), so this hydrates without re-writing.
        // Default light to preserve today's behaviour (§13.1 «light primary»); the user opts into dark/system.
        themePreference   = ThemePreference(rawValue: defaults.string(forKey: K.theme) ?? "") ?? .light
        language          = AppLanguage(rawValue: defaults.string(forKey: K.language) ?? "") ?? .ru
        faceIDUnlock      = defaults.object(forKey: K.faceID)   as? Bool ?? true
        pinEnabled        = defaults.object(forKey: K.pin)      as? Bool ?? true
        passkeysEnabled   = defaults.object(forKey: K.passkeys) as? Bool ?? false
        perOperationLimit = defaults.object(forKey: K.opLimit)  as? Double ?? 150_000
        notifyPush         = defaults.object(forKey: K.nPush) as? Bool ?? true
        notifyTransactions = defaults.object(forKey: K.nTx)   as? Bool ?? true
        notifySecurity     = defaults.object(forKey: K.nSec)  as? Bool ?? true
        notifyMarketing    = defaults.object(forKey: K.nMkt)  as? Bool ?? false
    }

    /// Available per-operation limit presets (₽); `0` is «без лимита».
    let operationLimitPresets: [Double] = [50_000, 150_000, 500_000, 0]

    func operationLimitLabel(_ value: Double) -> String {
        guard value > 0 else { return "Без лимита" }
        return MoneyFormat.fiat(value)
    }

    private enum K {
        static let theme = "settings.theme"
        static let language = "settings.language"
        static let faceID = "settings.security.faceID"
        static let pin = "settings.security.pin"
        static let passkeys = "settings.security.passkeys"
        static let opLimit = "settings.security.opLimit"
        static let nPush = "settings.notify.push"
        static let nTx = "settings.notify.tx"
        static let nSec = "settings.notify.security"
        static let nMkt = "settings.notify.marketing"
    }
}
