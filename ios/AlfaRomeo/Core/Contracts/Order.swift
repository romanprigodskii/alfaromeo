import Foundation

// Mirror of /shared (Order, §11.3) — keep in sync until codegen (Phase 0.3).

enum OrderSide: String, Codable, CaseIterable, Sendable {
    case buy, sell
}

enum OrderType: String, Codable, CaseIterable, Sendable {
    case market, limit
}

enum OrderStatus: String, Codable, CaseIterable, Sendable {
    case open, filled, partial, canceled, rejected
}

/// A crypto trading order (demo execution simulated by ``Crypto`` against live prices, §11.4).
struct Order: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let profileId: String
    let asset: String
    let side: OrderSide
    let type: OrderType
    let qty: Double
    var price: Double?     // nil for market orders until filled
    let status: OrderStatus
    let createdAt: String
}
