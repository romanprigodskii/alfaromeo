import SwiftUI

// 🆕 §11.3 — CDFA (ЦФА). Defined feature-locally (the Core contract doesn't carry it yet); demo data
// only. ЦФА — цифровые финансовые активы по 259-ФЗ: токенизированные инструменты от эмитентов через
// операторов информационных систем в реестре ЦБ. This is the *legal* digital-asset path (§2.4) — it
// is NOT subject to the crypto investor gating (квал/неквал, лимит 300к, тест на риски); only ordinary
// KYC applies. Priced natively in ₽.

enum CDFACategory: String, Codable, CaseIterable, Hashable, Sendable {
    case metal, bond, realEstate, equity, fund

    var label: String {
        switch self {
        case .metal:      return "Драгметаллы"
        case .bond:       return "Облигации"
        case .realEstate: return "Недвижимость"
        case .equity:     return "Доли / акции"
        case .fund:       return "Фонды"
        }
    }

    var icon: String {
        switch self {
        case .metal:      return "circle.hexagongrid.fill"
        case .bond:       return "doc.plaintext.fill"
        case .realEstate: return "building.2.fill"
        case .equity:     return "chart.pie.fill"
        case .fund:       return "square.stack.3d.up.fill"
        }
    }
}

/// A tokenized digital financial asset (ЦФА). `operatorName` is the оператор ИС registered with the
/// ЦБ; `issuer` is the эмитент. `yieldPct` is the stated annual доходность (0 for pure price assets).
struct CDFA: Identifiable, Hashable, Sendable {
    let id: String
    let ticker: String
    let name: String
    let issuer: String
    let operatorName: String
    let category: CDFACategory
    let priceRub: Double
    let yieldPct: Double
    let dayChangePct: Double
    let about: String
    let minUnits: Double

    /// The legal stamp shown across the ЦФА UI (§2.4).
    var registryNote: String { "В реестре ЦБ, 259-ФЗ" }
    var yieldLabel: String { yieldPct > 0 ? "\(MoneyFormat.percent(yieldPct, maxFractionDigits: 1)) годовых" : "Цена актива" }
}

/// A user's position in a ЦФА (mock-executed, feature-local).
struct CDFAHolding: Identifiable, Hashable, Sendable {
    let id: String
    let cdfaId: String
    var units: Double

    func valueRub(_ cdfa: CDFA) -> Double { units * cdfa.priceRub }
}
