import Foundation

// Explainable пре-квалификация (§10.5): a transparent affordability model whose every output is
// derived from three named factors — доход / долговая нагрузка / кредитная история — so the
// simulator can show an honest «если закрыть карту X — лимит +Y». The engine is pure; the store
// holds the borrower's inputs and the set of applied what-if levers.

/// The borrower inputs the limit model reads. Mutated (a copy) by simulator levers to recompute the
/// approved amount — never faked.
struct CreditProfileInputs: Hashable, Sendable {
    var monthlyIncome: Double      // подтверждённый доход, ₽/мес
    var monthlyDebt: Double        // сумма платежей по текущим обязательствам, ₽/мес
    var creditScore: Int           // скоринг (демо-шкала 300…850)
}

/// Status band for a single factor — colored honestly.
enum FactorStatus: Sendable {
    case good, ok, weak
    var label: String {
        switch self {
        case .good: return "Хорошо"
        case .ok:   return "Норма"
        case .weak: return "Слабо"
        }
    }
}

/// One explainable factor behind the decision (§10.5 «факторы решения»).
struct DecisionFactor: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case income, debtLoad, history
        var title: String {
            switch self {
            case .income:   return "Доход"
            case .debtLoad: return "Долговая нагрузка"
            case .history:  return "Кредитная история"
            }
        }
        var systemImage: String {
            switch self {
            case .income:   return "rublesign.circle"
            case .debtLoad: return "gauge.with.dots.needle.bottom.50percent"
            case .history:  return "chart.line.uptrend.xyaxis"
            }
        }
    }
    let kind: Kind
    var status: FactorStatus
    var valueLabel: String         // «195 000 ₽/мес», «ПДН 35%», «766 — высокий»
    var contribution: Double       // 0…1 — how strongly this factor supports the limit (bar fill)
    var weight: Double             // 0…1 — its share in the decision
    var explanation: String        // «почему так» простыми словами
    var improvement: String?       // «что улучшить» (nil когда фактор уже хороший)
    var id: String { kind.rawValue }
}

/// A what-if lever in the simulator (§10.5). Each toggles exactly one input; the store recomputes
/// the limit so the displayed Δ is exact.
struct SimulatorLever: Identifiable, Hashable, Sendable {
    enum Effect: Hashable, Sendable {
        case closeObligation(id: String, monthlyPayment: Double)  // − monthlyDebt
        case confirmIncome(extra: Double)                          // + monthlyIncome
        case cleanHistory(scoreBoost: Int)                         // + creditScore
    }
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let effect: Effect
}

/// Pure pre-qualification engine — capacity → limit, factors, personalised rate. Same annuity core
/// as the repayment schedule (``LoanMath``), so «сколько одобрят» and «сколько платить» never drift.
enum PrequalEngine {
    static let maxDTI = 0.50            // ПДН-cap: debt service ≤ 50% of income (банковский ориентир)
    static let referenceTermMonths = 60 // limit capitalised over the longest sensible term
    static let scoreFloor = 600         // ниже — отказ (тонкое досье / плохая история)

    /// Свободный платёж/мес = доход×maxDTI − текущие платежи.
    static func capacity(_ inp: CreditProfileInputs) -> Double {
        max(0, inp.monthlyIncome * maxDTI - inp.monthlyDebt)
    }

    static func dti(_ inp: CreditProfileInputs) -> Double {
        guard inp.monthlyIncome > 0 else { return 1 }
        return min(1, inp.monthlyDebt / inp.monthlyIncome)
    }

    /// История-множитель к лимиту: 600→0.33 … 800→1.0 … 850→1.17 (clamped 0…1.15).
    static func historyMultiplier(score: Int) -> Double {
        min(1.15, max(0, (Double(score) - 500) / 300))
    }

    /// Персональная ставка внутри [min,max]: лучше скоринг → ближе к минимуму. Рассрочка → 0%.
    static func rate(for product: CreditProduct, score: Int) -> Double {
        guard !product.kind.isInterestFree else { return 0 }
        let t = min(1, max(0, Double(score - scoreFloor) / 250))   // 600→0, 850→1
        return product.maxRate - (product.maxRate - product.minRate) * t
    }

    /// Explainable approved limit for a product given inputs. 0 ⇒ отказ (score below the floor).
    static func approvedLimit(for product: CreditProduct, inputs inp: CreditProfileInputs) -> Double {
        guard inp.creditScore >= scoreFloor else { return 0 }
        let cap = capacity(inp)
        guard cap > 0 else { return 0 }
        let r = rate(for: product, score: inp.creditScore)
        let term = min(referenceTermMonths, product.termOptionsMonths.max() ?? referenceTermMonths)
        let raw = LoanMath.maxPrincipal(payment: cap, annualRatePercent: r, months: term)
        let scaled = raw * historyMultiplier(score: inp.creditScore)
        let clean = (scaled / 10_000).rounded(.down) * 10_000     // round down to a clean 10k
        return min(product.maxAmount, max(0, clean))
    }

    /// The three decision factors for a set of inputs (§10.5 доход / нагрузка / история).
    static func factors(_ inp: CreditProfileInputs) -> [DecisionFactor] {
        let d = dti(inp)
        // Доход
        let income = DecisionFactor(
            kind: .income,
            status: inp.monthlyIncome >= 120_000 ? .good : (inp.monthlyIncome >= 60_000 ? .ok : .weak),
            valueLabel: "\(CreditFormat.rub(inp.monthlyIncome))/мес",
            contribution: min(1, inp.monthlyIncome / 300_000),
            weight: 0.40,
            explanation: "Подтверждённый доход задаёт потолок: банк закладывает платёж не выше \(MoneyFormat.percent(fraction: maxDTI, maxFractionDigits: 0)) от дохода.",
            improvement: inp.monthlyIncome >= 120_000 ? nil
                : "Подтвердите доход справкой 2-НДФЛ или выпиской, и потолок платежа вырастет.")
        // Долговая нагрузка (ПДН)
        let debt = DecisionFactor(
            kind: .debtLoad,
            status: d < 0.25 ? .good : (d <= 0.40 ? .ok : .weak),
            valueLabel: "ПДН \(MoneyFormat.percent(fraction: d, maxFractionDigits: 0))",
            contribution: max(0, 1 - d / maxDTI),
            weight: 0.30,
            explanation: "Текущие платежи \(CreditFormat.rub(inp.monthlyDebt))/мес уже занимают часть дохода. Чем меньше нагрузка, тем больше свободного платежа под новый кредит.",
            improvement: d < 0.25 ? nil
                : "Закройте кредитную карту или микрозайм: ПДН снизится, лимит вырастет.")
        // Кредитная история (скоринг)
        let history = DecisionFactor(
            kind: .history,
            status: inp.creditScore >= 740 ? .good : (inp.creditScore >= 660 ? .ok : .weak),
            valueLabel: "\(inp.creditScore), \(scoreWord(inp.creditScore))",
            contribution: min(1, historyMultiplier(score: inp.creditScore) / 1.0),
            weight: 0.30,
            explanation: "Скоринг по данным БКИ влияет и на ставку, и на множитель лимита. Без просрочек он растёт.",
            improvement: inp.creditScore >= 740 ? nil
                : "Гасите платежи вовремя 6 месяцев: скоринг вырастет, ставка снизится.")
        return [income, debt, history]
    }

    private static func scoreWord(_ score: Int) -> String {
        switch score {
        case 740...:    return "высокий"
        case 660..<740: return "средний"
        default:        return "низкий"
        }
    }
}
