import Foundation

/// Pure annuity-loan math — the single calculation core shared by the application wizard (платёж /
/// график) and the explainable pre-qualification limit (its inverse, §10.5). All money in ₽, rate as
/// an annual percent (e.g. `25.9`), term in whole months. No state, no side effects → trivially
/// testable, and the same engine drives both «сколько одобрят» and «сколько платить».
enum LoanMath {
    /// Monthly annuity payment for a fully-amortising loan. Falls back to straight-line for a 0%
    /// rate (рассрочка) and guards degenerate input.
    static func monthlyPayment(principal: Double, annualRatePercent rate: Double, months: Int) -> Double {
        guard principal > 0, months > 0 else { return 0 }
        let r = rate / 100 / 12
        guard r > 0 else { return principal / Double(months) }          // 0% рассрочка
        let factor = pow(1 + r, Double(months))
        return principal * r * factor / (factor - 1)
    }

    /// Inverse of ``monthlyPayment``: the largest principal whose annuity payment still fits inside
    /// `payment` at this rate/term. The pre-qual capitalises a borrower's free monthly capacity
    /// (доход − текущие платежи) into an approved limit — so every simulator Δ is *derived* from this
    /// same formula, not invented (§10.5 «факторы решения + симулятор»).
    static func maxPrincipal(payment: Double, annualRatePercent rate: Double, months: Int) -> Double {
        guard payment > 0, months > 0 else { return 0 }
        let r = rate / 100 / 12
        guard r > 0 else { return payment * Double(months) }
        let factor = pow(1 + r, Double(months))
        return payment * (factor - 1) / (r * factor)
    }

    /// Full amortisation schedule — one row per month with the principal/interest split and the
    /// running balance. The final row absorbs any rounding residue so the balance lands on 0.
    static func schedule(principal: Double, annualRatePercent rate: Double, months: Int) -> [ScheduleRow] {
        guard principal > 0, months > 0 else { return [] }
        let payment = monthlyPayment(principal: principal, annualRatePercent: rate, months: months)
        let r = rate / 100 / 12
        var balance = principal
        var rows: [ScheduleRow] = []
        rows.reserveCapacity(months)
        for i in 1...months {
            let interest = balance * r
            var principalPart = payment - interest
            if i == months { principalPart = balance }   // clear residue on the last month
            balance = max(0, balance - principalPart)
            rows.append(ScheduleRow(index: i, payment: interest + principalPart,
                                    principalPart: principalPart, interestPart: interest, balance: balance))
        }
        return rows
    }

    static func totalPaid(principal: Double, annualRatePercent rate: Double, months: Int) -> Double {
        monthlyPayment(principal: principal, annualRatePercent: rate, months: months) * Double(months)
    }

    static func overpay(principal: Double, annualRatePercent rate: Double, months: Int) -> Double {
        max(0, totalPaid(principal: principal, annualRatePercent: rate, months: months) - principal)
    }
}

/// One month of an amortisation schedule (§10.5 «расчёт платежа/графика»).
struct ScheduleRow: Identifiable, Hashable {
    let index: Int            // 1-based month number
    let payment: Double
    let principalPart: Double // основной долг
    let interestPart: Double  // проценты
    let balance: Double       // остаток после платежа
    var id: Int { index }
}
