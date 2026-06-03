import Foundation

/// A corporate card issued to an employee (§8.2 «корп-карты … лимиты, управление расходами»).
/// Feature-local and lightweight: the Cards module owns the full issuance pipeline; here we model
/// just what the «Команда» section manages — holder, masked tail, monthly limit + spend, freeze.
struct CorporateCard: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Identifiable, Hashable, Sendable {
        case virtual, plastic
        var id: String { rawValue }
        var label: String { self == .virtual ? "Виртуальная" : "Пластиковая" }
        var icon: String { self == .virtual ? "creditcard" : "creditcard.fill" }
    }

    enum State: String, Hashable, Sendable {
        case active, frozen
        var label: String { self == .active ? "Активна" : "Заморожена" }
    }

    let id: String
    let holderUserId: String
    var holderName: String
    var kind: Kind
    var last4: String
    var monthlyLimit: Double
    var monthlySpent: Double
    var state: State

    var holderInitials: String {
        let parts = holderName.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "?" : parts.map(String.init).joined().uppercased()
    }

    /// 0…1 fraction of the monthly cap used (drives the ``ProgressBar`` gauge).
    var spentProgress: Double {
        guard monthlyLimit > 0 else { return 0 }
        return min(monthlySpent / monthlyLimit, 1)
    }
    var remaining: Double { max(monthlyLimit - monthlySpent, 0) }
    var isFrozen: Bool { state == .frozen }
    var maskedPan: String { "•• \(last4)" }
}
