import SwiftUI

// 🆕 §11.3 — ExternalWallet. Defined feature-locally; demo only. A watch-only link to a self-custody
// wallet (MetaMask / Trust / Ledger / TON). We do NOT connect to any chain — balances are mock,
// derived deterministically from the pasted address, and valued at live ₽ prices. The wallet appears
// in the unified portfolio strictly read-only (no send/receive/convert from it).

enum ExternalWalletProvider: String, CaseIterable, Identifiable, Hashable, Sendable {
    case metaMask, trustWallet, ledger, tonWallet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metaMask:    return "MetaMask"
        case .trustWallet: return "Trust Wallet"
        case .ledger:      return "Ledger"
        case .tonWallet:   return "TON Wallet"
        }
    }

    var tagline: String {
        switch self {
        case .metaMask:    return "EVM · по адресу 0x…"
        case .trustWallet: return "Мультичейн · по адресу"
        case .ledger:      return "Аппаратный · только просмотр"
        case .tonWallet:   return "TON · по адресу"
        }
    }

    var icon: String {
        switch self {
        case .metaMask:    return "cube.transparent.fill"
        case .trustWallet: return "checkmark.shield.fill"
        case .ledger:      return "externaldrive.fill"
        case .tonWallet:   return "diamond.fill"
        }
    }

    var isHardware: Bool { self == .ledger }

    /// A plausible placeholder address shape for the link field.
    var addressPlaceholder: String {
        switch self {
        case .metaMask, .trustWallet, .ledger: return "0x… (EVM-адрес)"
        case .tonWallet:                        return "EQ… / UQ… (TON-адрес)"
        }
    }

    /// The assets a mock link of this provider surfaces (valued live).
    var mockAssets: [String] {
        switch self {
        case .metaMask:    return ["ETH", "USDT"]
        case .trustWallet: return ["BTC", "ETH"]
        case .ledger:      return ["BTC", "ETH", "USDT"]
        case .tonWallet:   return ["TON", "USDT"]
        }
    }
}

/// A single asset balance inside an external wallet (mock).
struct ExternalHolding: Identifiable, Hashable, Sendable {
    let asset: String
    let balance: Double
    var id: String { asset }
}

/// A linked, watch-only external wallet shown in the unified portfolio (read-only).
struct ExternalWallet: Identifiable, Hashable, Sendable {
    let id: String
    let provider: ExternalWalletProvider
    let address: String
    var label: String
    let holdings: [ExternalHolding]

    /// Short masked address, e.g. `0x9f…A21c`.
    var shortAddress: String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
