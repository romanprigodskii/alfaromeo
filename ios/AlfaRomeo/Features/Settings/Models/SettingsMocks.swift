import Foundation

/// Demo identity shown on the Профиль screen (§9.8 «Мои документы Паспорт/ИНН», «Обо мне»).
///
/// The `User` contract only carries `phone` (no name/email/passport/ИНН yet), so — like the История
/// module's category overrides — these extra fields live here as clearly-labelled demo data rather
/// than widening the Core contract. Phone is the one real field, passed through from the session user.
struct ProfileIdentity {
    var fullName: String
    var email: String
    var passportMasked: String
    var innMasked: String

    /// Deterministic demo identity (so screenshots are stable). Name falls back to the profile's
    /// display name; phone comes from the real `User`.
    static func demo(displayName: String?) -> ProfileIdentity {
        ProfileIdentity(
            fullName: displayName ?? "Александр Романов",
            email: "a.romanov@romeo.bank",
            passportMasked: "45 •• ••8821",
            innMasked: "7•• ••• •• 4417"
        )
    }
}

/// A person in «Близкие» (§9.8 / §5.1 joint) — demo only.
struct CloseContact: Identifiable, Hashable {
    let id: String
    let name: String
    let relation: String
    let initials: String

    static let demo: [CloseContact] = [
        CloseContact(id: "c1", name: "Мария Романова", relation: "Супруга, общий бюджет", initials: "М"),
        CloseContact(id: "c2", name: "Пётр Романов", relation: "Сын, детская карта", initials: "П"),
    ]
}

/// A signed-in device / session (§9.8 «Безопасность → устройства/сессии») — demo only.
struct DeviceSession: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let icon: String
    let isCurrent: Bool

    static let demo: [DeviceSession] = [
        DeviceSession(id: "d1", name: "iPhone 17 Pro", detail: "Москва, сейчас",
                      icon: "iphone", isCurrent: true),
        DeviceSession(id: "d2", name: "iPad Air", detail: "Москва, 2 дня назад", icon: "ipad", isCurrent: false),
        DeviceSession(id: "d3", name: "Chrome · macOS", detail: "Веб-кабинет, 5 дней назад",
                      icon: "desktopcomputer", isCurrent: false),
    ]
}
