import Foundation

/// Назначение оплаты связи (§7.2 «Оплата связи», §7.1 роуминг криптой).
enum MobilePaymentPurpose: String, Hashable, Sendable {
    case topUp      // пополнить счёт связи
    case roaming    // оплатить роуминг (вход в крипто-оплату)
    case tariff     // оплатить смену тарифа

    var title: String {
        switch self {
        case .topUp:   return "Оплата связи"
        case .roaming: return "Оплата роуминга"
        case .tariff:  return "Оплата тарифа"
        }
    }
    var prompt: String {
        switch self {
        case .topUp:   return "Пополните счёт Ромео Mobile с любого счёта, включая крипту."
        case .roaming: return "Оплатите роуминг криптой или стейблкоинами."
        case .tariff:  return "Спишем стоимость тарифа с выбранного счёта."
        }
    }
    var icon: String {
        switch self {
        case .topUp:   return "creditcard.fill"
        case .roaming: return "airplane.circle.fill"
        case .tariff:  return "arrow.up.circle.fill"
        }
    }
    /// Roaming pay-in leads with crypto/stable sources (§7.1).
    var prefersCrypto: Bool { self == .roaming }
}

/// A unified pay-from source: any fiat/цифр.₽ account or a crypto wallet (§7.1 «с любого счёта (вкл. крипту)»).
enum PaymentSource: Identifiable, Hashable, Sendable {
    case account(Account)
    case wallet(CryptoWallet)

    var id: String {
        switch self {
        case .account(let a): return "acc_" + a.id
        case .wallet(let w):  return "wal_" + w.id
        }
    }
    var isCrypto: Bool {
        switch self {
        case .account(let a): return a.type == .crypto
        case .wallet:         return true
        }
    }
    var title: String {
        switch self {
        case .account(let a):
            switch a.type {
            case .current:      return "Текущий счёт"
            case .savings:      return "Накопительный"
            case .crypto:       return "Крипто-счёт · \(a.currency)"
            case .digitalRuble: return "Цифровой рубль"
            }
        case .wallet(let w):    return "\(w.asset) · \(w.chain.capitalized)"
        }
    }
    var balanceLabel: String {
        switch self {
        case .account(let a): return MoneyFormat.amount(a.balance, currency: a.currency)
        case .wallet(let w):  return MoneyFormat.amount(w.balance, currency: w.asset)
        }
    }
    var icon: String {
        switch self {
        case .account(let a):
            switch a.type {
            case .current:      return "banknote.fill"
            case .savings:      return "building.columns.fill"
            case .crypto:       return "bitcoinsign.circle.fill"
            case .digitalRuble: return "rublesign.circle.fill"
            }
        case .wallet:           return "bitcoinsign.circle.fill"
        }
    }
}

/// A recorded mobile payment (demo history shown on the hub / payment screens).
struct MobilePayment: Identifiable, Hashable, Sendable {
    let id: String
    let purpose: MobilePaymentPurpose
    let amount: Double          // ₽-equivalent
    let sourceTitle: String
    let isCrypto: Bool
}
