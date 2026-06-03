import SwiftUI

/// A user-defined category created in «Мои категории» (§9.4). Session-local (held by ``HistoryStore``)
/// since the contract has no category schema yet — colors are stored as a packed hex so the model
/// stays `Sendable`/`Hashable` without leaning on `Color`'s equality.
struct CustomCategory: Identifiable, Hashable, Sendable {
    let id: String          // "custom_<n>"
    var title: String
    var iconName: String
    var tintHex: UInt32
}

/// A resolved category reference — a built-in ``TransactionCategory`` *or* a ``CustomCategory``,
/// flattened to the few fields every History surface needs (icon · tint · title · id). Using one type
/// across the picker, the feed row, the detail chip, and the analytics slices lets custom categories
/// behave exactly like built-ins everywhere (§10.7). Identity is the `id` alone, so a ref compares and
/// hashes by category regardless of how its tint was sourced.
struct CategoryRef: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let icon: String
    let tintHex: UInt32
    let isCustom: Bool

    var tint: Color { Color(hex: tintHex) }

    init(_ builtin: TransactionCategory) {
        id = builtin.rawValue; title = builtin.title; icon = builtin.icon
        tintHex = builtin.tintHex; isCustom = false
    }

    init(_ custom: CustomCategory) {
        id = custom.id; title = custom.title; icon = custom.iconName
        tintHex = custom.tintHex; isCustom = true
    }

    static func == (lhs: CategoryRef, rhs: CategoryRef) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
