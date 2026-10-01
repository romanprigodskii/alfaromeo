import SwiftUI

/// Display + synthesized requisites for the account detail (§9.1).
///
/// The `Account` contract carries only `{id, profileId, type, currency, balance}` — no human number
/// or banking requisites. The detail screen needs both, so this file **derives them deterministically
/// from the account id** (stable across launches, never random — mirrors how the History feed derives
/// a tx→account association heuristically in ``HistoryFilter``). Demo values only; no real
/// PAN/requisites exist client-side (§11.8). Reuses the existing ``Account`` display helpers
/// (`symbol` / `displayTitle` / `type.paymentsIcon`, defined in the Payments module) — no duplicates.

// MARK: - Deterministic identifiers (no RNG, no Date — stable per id)

enum AccountIdentifiers {
    /// `count` pseudo-digits derived from `seed` via FNV-1a per index. Same seed → same string.
    static func digits(seed: String, count: Int) -> String {
        var out = ""
        for i in 0..<count {
            var hash: UInt64 = 1469598103934665603       // FNV-1a offset basis
            for byte in "\(seed)#\(i)".utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            out.append(Character(String(hash % 10)))
        }
        return out
    }

    /// A TRON-style watch-only address (demo), stable per seed.
    static func address(seed: String) -> String {
        let charset = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz123456789")
        var out = "T"
        for i in 0..<33 {
            var hash: UInt64 = 1469598103934665603
            for byte in "\(seed)@\(i)".utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            out.append(charset[Int(hash % UInt64(charset.count))])
        }
        return out
    }
}

// MARK: - Requisites view-model

/// The reveal-and-copy requisites for one account: a banking set for ₽ accounts, a wallet address for
/// the crypto account. Built once via ``make(for:holder:)``.
struct AccountRequisites {
    let isCrypto: Bool
    // Fiat (current / savings / digital ₽)
    let accountNumberFull: String       // "40817 810 4 0000 1234567"
    let accountNumberMasked: String     // "•••• 4567"
    let bik: String
    let corrAccount: String
    let bankName: String
    let holder: String
    let inn: String
    // Crypto
    let address: String
    let addressMasked: String
    let network: String

    /// ОКВ code in the account number (digits 6-8): 810 ₽, 840 USD, 978 EUR, 156 CNY.
    private static func currencyNumCode(_ currency: String) -> String {
        FxRateClient.seedTable.quotes[currency.uppercased()]?.numCode ?? "810"
    }

    static func make(for account: Account, holder: String) -> AccountRequisites {
        if account.type == .crypto {
            let addr = AccountIdentifiers.address(seed: account.id)
            let cur = account.currency.uppercased()
            return AccountRequisites(
                isCrypto: true,
                accountNumberFull: "", accountNumberMasked: "",
                bik: "", corrAccount: "", bankName: "", holder: holder, inn: "",
                address: addr,
                addressMasked: "\(addr.prefix(6))…\(addr.suffix(4))",
                network: cur == "USDT" ? "TRC-20 · USDT" : "ERC-20 · \(cur)"
            )
        }
        let tail = AccountIdentifiers.digits(seed: account.id, count: 7)
        let check = AccountIdentifiers.digits(seed: account.id + "k", count: 1)
        return AccountRequisites(
            isCrypto: false,
            accountNumberFull: "40817 \(currencyNumCode(account.currency)) \(check) 0000 \(tail)",
            accountNumberMasked: "•••• \(tail.suffix(4))",
            bik: "044525974",
            corrAccount: "30101 810 2 0000 0000974",
            bankName: "Ромео Банк",
            holder: holder,
            inn: AccountIdentifiers.digits(seed: account.profileId + "inn", count: 12),
            address: "", addressMasked: "", network: ""
        )
    }
}

// MARK: - ₽ valuation (same live source / pegging as the Crypto Hub & business Счета, §2.4)

@MainActor
enum AccountValuation {
    /// ₽ for one unit of a currency: ₽ is 1:1; fiat (USD, EUR, CNY…) at the official курс ЦБ
    /// (``FXRateService``); the stablecoins off the live USDT tick; any other crypto symbol reads the
    /// price book directly. Business Счета use this same function.
    static func rubRate(currency: String, prices: LivePriceService) -> Double {
        let code = currency.uppercased()
        switch code {
        case "RUB":            return 1
        case "USDT", "USDC":   return prices.price("USDT")
        default:
            let fx = FXRateService.shared
            return fx.isFiat(code) ? fx.rate(code) : prices.price(code)
        }
    }

    /// Foreign fiat (not ₽, not crypto) — valued and labelled by курс ЦБ.
    static func isForeignFiat(_ currency: String) -> Bool {
        currency.uppercased() != "RUB" && FXRateService.shared.isFiat(currency)
    }

    static func rubValue(_ account: Account, prices: LivePriceService) -> Double {
        account.balance * rubRate(currency: account.currency, prices: prices)
    }
}

// MARK: - Quick actions (each leads to a real, working destination)

/// One quick-action tile in the detail header. Wiring (per ``AccountType``):
/// ₽ accounts → пополнение/перевод через ``PaymentsRoute.transfer`` + лист реквизитов;
/// crypto → приём (адрес) / отправка (`cryptoToContact`) / переход в Crypto Hub.
struct AccountQuickAction: Identifiable {
    enum Kind: Equatable {
        case transfer(TransferKind)   // → PaymentsRoute.transfer on the Home stack
        case requisites               // → AccountRequisitesSheet
        case cryptoHub                // → HomeRoute.crypto
    }

    let id: String
    let title: String
    let icon: String
    let kind: Kind

    static func actions(for type: AccountType) -> [AccountQuickAction] {
        switch type {
        case .current, .savings:
            return [
                AccountQuickAction(id: "topup", title: "Пополнить",  icon: "arrow.down.circle.fill",   kind: .transfer(.betweenAccounts)),
                AccountQuickAction(id: "send",  title: "Перевести",  icon: "arrow.up.right.circle.fill", kind: .transfer(.byPhone)),
                AccountQuickAction(id: "req",   title: "Реквизиты",  icon: "doc.text.fill",            kind: .requisites),
            ]
        case .digitalRuble:
            return [
                AccountQuickAction(id: "topup", title: "Пополнить",  icon: "arrow.down.circle.fill", kind: .transfer(.betweenAccounts)),
                AccountQuickAction(id: "send",  title: "Перевести",  icon: "qrcode",                 kind: .transfer(.digitalRubleQR)),
                AccountQuickAction(id: "req",   title: "Реквизиты",  icon: "doc.text.fill",          kind: .requisites),
            ]
        case .crypto:
            return [
                AccountQuickAction(id: "receive", title: "Принять",    icon: "arrow.down.circle.fill",   kind: .requisites),
                AccountQuickAction(id: "send",    title: "Отправить",  icon: "arrow.up.right.circle.fill", kind: .transfer(.cryptoToContact)),
                AccountQuickAction(id: "hub",     title: "Биржа",      icon: "bitcoinsign.circle.fill",  kind: .cryptoHub),
            ]
        }
    }
}
