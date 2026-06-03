import SwiftUI

/// The user's app-theme choice (§9.8 «Тема»). Drives the real color scheme of the whole app via
/// ``ThemeProvider`` at the root. `system` follows the device; `light`/`dark` pin the scheme. The dark
/// palette already exists in ``Theme`` — this just gives the user access to it.
enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Система"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        }
    }

    /// `nil` → no preference (follow the device); otherwise pin light/dark.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// Interface language (§9.8 «Язык»). Selection persists; localization itself is a later phase, so the
/// UI stays Russian — the picker is an honest stub today.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case ru, en

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    var nativeFlag: String {
        switch self {
        case .ru: return "🇷🇺"
        case .en: return "🇬🇧"
        }
    }
}
