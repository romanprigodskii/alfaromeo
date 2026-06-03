import Foundation

/// Член семейного пакета (§7.1): шеринг ГБ с профилями «Близкие»/детский.
struct FamilyShareMember: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case me, close, child

        var label: String {
            switch self {
            case .me:    return "Вы"
            case .close: return "Близкие"
            case .child: return "Детский"
            }
        }
        var icon: String {
            switch self {
            case .me:    return "person.fill"
            case .close: return "person.2.fill"
            case .child: return "figure.child"
            }
        }
    }

    let id: String
    var name: String
    var kind: Kind
    var allocatedGb: Double
    var usedGb: Double

    var remainingGb: Double { max(0, allocatedGb - usedGb) }
    var usedFraction: Double { allocatedGb > 0 ? min(1, usedGb / allocatedGb) : 0 }
    var initials: String {
        String(name.trimmingCharacters(in: .whitespaces).first.map(String.init) ?? "?").uppercased()
    }
}
