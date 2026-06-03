import Foundation

/// How a physical card is delivered (§6.2). Cost depends on the active tier.
enum DeliveryMethod: String, CaseIterable, Identifiable, Sendable {
    case courier, post, branch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .courier: return "Курьером"
        case .post:    return "Почтой"
        case .branch:  return "В отделении"
        }
    }

    var detail: String {
        switch self {
        case .courier: return "1–2 дня, до двери"
        case .post:    return "5–7 дней"
        case .branch:  return "Забрать самому, сегодня"
        }
    }

    var icon: String {
        switch self {
        case .courier: return "bicycle"
        case .post:    return "envelope"
        case .branch:  return "building.columns"
        }
    }

    /// List price before tier discount, ₽.
    var basePrice: Double {
        switch self {
        case .courier: return 490
        case .post:    return 290
        case .branch:  return 0
        }
    }

    /// Tier-adjusted price (§6.2 "стоимость по тиру"): Pro −50%, Infinite/Corp free.
    func price(for tier: Tier) -> Double {
        switch tier {
        case .infinite, .bizCorp: return 0
        case .pro, .bizPro:       return basePrice / 2
        default:                  return basePrice
        }
    }

    func priceLabel(for tier: Tier) -> String {
        let p = price(for: tier)
        return p == 0 ? "Бесплатно" : "\(Int(p)) ₽"
    }
}

/// Physical-card fulfilment, mutable so the tracking screen can animate the status (§6.2 / §6.4).
struct DeliveryOrder: Identifiable, Hashable, Sendable {
    let id: String
    /// The issued card this plastic belongs to (nil for legacy API fixtures).
    let cardId: String?
    let cardType: CardType
    var designId: String
    var status: PhysicalCardStatus
    var tracking: String
    var address: String
    var method: DeliveryMethod
    var orderedAt: Date?

    /// True once the card has arrived (awaiting activation it still reads delivered).
    var isDelivered: Bool { status == .delivered }
}

extension DeliveryOrder {
    /// Hydrate from the read-only API `CardOrder` fixture.
    init(from order: CardOrder) {
        self.init(
            id: order.id,
            cardId: nil,
            cardType: order.cardType,
            designId: order.designId ?? CardDesign.base.id,
            status: order.physicalStatus == .none ? .ordered : order.physicalStatus,
            tracking: order.tracking ?? "—",
            address: order.address ?? "—",
            method: .courier,
            orderedAt: nil
        )
    }
}

extension PhysicalCardStatus {
    /// The ordered animated stages for the stepper (excludes `.none`).
    static let deliveryStages: [PhysicalCardStatus] = [.ordered, .printing, .shipping, .delivered]

    var stageIndex: Int { Self.deliveryStages.firstIndex(of: self) ?? 0 }

    var title: String {
        switch self {
        case .none:      return "—"
        case .ordered:   return "Оформлена"
        case .printing:  return "Печать"
        case .shipping:  return "В пути"
        case .delivered: return "Доставлена"
        }
    }

    var icon: String {
        switch self {
        case .none:      return "questionmark"
        case .ordered:   return "doc.text"
        case .printing:  return "printer.fill"
        case .shipping:  return "shippingbox.fill"
        case .delivered: return "checkmark.seal.fill"
        }
    }

    /// The next stage in the pipeline, or nil at the end.
    var next: PhysicalCardStatus? {
        guard let i = Self.deliveryStages.firstIndex(of: self),
              i + 1 < Self.deliveryStages.count else { return nil }
        return Self.deliveryStages[i + 1]
    }
}
