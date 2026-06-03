import SwiftUI

/// One capability a ``MembershipRole`` may hold inside a business profile (§5.3, §8.2). The matrix
/// below is the demo's «права» — what each role is allowed to do. Signing (`signPayments`) is the one
/// that powers the multi-step 2-of-N подпись (§11.8).
enum TeamPermission: String, CaseIterable, Identifiable, Hashable, Sendable {
    case viewFinance        // дашборд, балансы, выписки
    case createPayments     // создавать платежи/счета
    case signPayments       // подписывать крупные платежи (2-of-N)
    case managePayroll      // зарплатные реестры
    case manageAcquiring    // точки эквайринга
    case issueCards         // выпуск корп-карт
    case manageTeam         // команда и роли
    case viewAnalytics      // аналитика, налоги, кассовый разрыв

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewFinance:     return "Балансы и выписки"
        case .createPayments:  return "Создание платежей"
        case .signPayments:    return "Подпись платежей (2-of-N)"
        case .managePayroll:   return "Зарплатные реестры"
        case .manageAcquiring: return "Эквайринг"
        case .issueCards:      return "Выпуск корп-карт"
        case .manageTeam:      return "Команда и роли"
        case .viewAnalytics:   return "Аналитика и налоги"
        }
    }

    var icon: String {
        switch self {
        case .viewFinance:     return "doc.text.magnifyingglass"
        case .createPayments:  return "paperplane"
        case .signPayments:    return "signature"
        case .managePayroll:   return "person.3.sequence.fill"
        case .manageAcquiring: return "qrcode"
        case .issueCards:      return "creditcard"
        case .manageTeam:      return "person.2.badge.gearshape"
        case .viewAnalytics:   return "chart.line.uptrend.xyaxis"
        }
    }
}

/// The role catalogue for the business team (§8.2: владелец / бухгалтер / менеджер). Maps the
/// contract's ``MembershipRole`` to a localized label, an accent tint, and the permission set the
/// «Команда и роли» matrix renders. `admin`/`member` fold onto the nearest of the three demo roles.
enum RoleCatalog {
    /// The three roles surfaced in the business demo, in authority order.
    static let demoRoles: [MembershipRole] = [.owner, .accountant, .manager]

    static func label(_ role: MembershipRole) -> String {
        switch role {
        case .owner:      return "Владелец"
        case .admin:      return "Администратор"
        case .accountant: return "Бухгалтер"
        case .manager:    return "Менеджер"
        case .member:     return "Сотрудник"
        }
    }

    static func blurb(_ role: MembershipRole) -> String {
        switch role {
        case .owner:      return "Полный доступ, управление командой и подписи."
        case .admin:      return "Администрирование без смены владельца."
        case .accountant: return "Платежи, реестры, подпись крупных операций."
        case .manager:    return "Создаёт платежи и работает с эквайрингом."
        case .member:     return "Базовый доступ к операциям."
        }
    }

    static func icon(_ role: MembershipRole) -> String {
        switch role {
        case .owner:      return "crown.fill"
        case .admin:      return "gearshape.fill"
        case .accountant: return "function"
        case .manager:    return "briefcase.fill"
        case .member:     return "person.fill"
        }
    }

    /// Role tint. Read where a solid chip is drawn (contrast handled by `bestOnColor`).
    static func tint(_ role: MembershipRole, theme: Theme) -> Color {
        switch role {
        case .owner, .admin:  return theme.accent
        case .accountant:     return BrandColors.cryptoBlue
        case .manager:        return theme.warning
        case .member:         return theme.textSecondary
        }
    }

    /// Permissions granted to a role (§8.2 «права»). Owner is all-powerful; accountant signs and runs
    /// payroll; manager creates payments and works acquiring but cannot sign or touch the team.
    static func permissions(_ role: MembershipRole) -> Set<TeamPermission> {
        switch role {
        case .owner, .admin:
            return Set(TeamPermission.allCases)
        case .accountant:
            return [.viewFinance, .createPayments, .signPayments, .managePayroll, .viewAnalytics]
        case .manager:
            return [.viewFinance, .createPayments, .manageAcquiring]
        case .member:
            return [.viewFinance]
        }
    }

    /// Roles allowed to sign a multi-step approval (§11.8). Only владелец и бухгалтер.
    static func canSign(_ role: MembershipRole) -> Bool {
        permissions(role).contains(.signPayments)
    }
}

/// A teammate inside the business profile — the contract ``Membership`` enriched with the display
/// data the UI needs (name, initials, contact). Feature-local: the backend slice exposes a single
/// `membership(profileId:)`, so the team roster is seeded in ``TeamStore`` for the demo.
struct TeamMember: Identifiable, Hashable, Sendable {
    let id: String              // userId
    var name: String
    var role: MembershipRole
    var email: String
    var isCurrentUser: Bool
    var joinedAt: Date

    var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "?" : parts.map(String.init).joined().uppercased()
    }

    var roleLabel: String { RoleCatalog.label(role) }
    var permissions: Set<TeamPermission> { RoleCatalog.permissions(role) }
    var canSign: Bool { RoleCatalog.canSign(role) }

    /// The contract membership this member maps to (kept in sync with the role).
    func membership(profileId: String) -> Membership {
        Membership(userId: id, profileId: profileId, role: role,
                   permissions: permissions.map(\.rawValue).sorted())
    }
}
