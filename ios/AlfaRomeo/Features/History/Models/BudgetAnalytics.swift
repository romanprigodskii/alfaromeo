import Foundation

// MARK: - Feed grouping (§9.4 «группы по датам»)

/// One day's worth of operations for the feed, newest day first.
struct DaySection: Identifiable {
    let id: String          // "yyyy-MM-dd" (stable key)
    let date: Date
    let title: String       // «Сегодня» / «Вчера» / "2 июня"
    let net: Double         // signed sum of the day's amounts (header figure)
    let transactions: [Transaction]
}

// MARK: - Analytics

/// The three analytics tabs (§9.4: «Расходы / Доходы / Вся аналитика»).
enum AnalyticsScope: String, CaseIterable, Identifiable, Hashable {
    case expense, income, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expense: return "Расходы"
        case .income:  return "Доходы"
        case .all:     return "Вся аналитика"
        }
    }
}

/// A category's share within a period — one donut sector + one list row. Keyed by ``CategoryRef`` so
/// built-in and user-defined categories slice identically (§10.7).
struct CategorySlice: Identifiable {
    let category: CategoryRef
    let amount: Double      // positive magnitude
    let count: Int
    var id: String { category.id }
    func percent(of total: Double) -> Double { total > 0 ? amount / total : 0 }
}

/// Income vs. expense for one calendar month — feeds the «Вся аналитика» bar chart.
struct MonthlySummary: Identifiable {
    let monthKey: String    // "yyyy-MM"
    let date: Date          // first instant of the month
    let income: Double      // positive
    let expense: Double     // positive magnitude
    var id: String { monthKey }
    var net: Double { income - expense }
    var label: String { HistoryFormatting.monthShort(date) }
}

/// A static AI-style insight card (§10.7 «AI-прогноз / аномалии»). Real model-backed insights land in
/// Фаза 3 (§10.9) — these are deterministically computed from the fixtures and clearly marked demo.
struct AIInsight: Identifiable {
    enum Kind { case forecast, anomaly, tip }
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

enum BudgetAnalytics {
    private static let cal = HistoryFormatting.calendar

    /// Distinct months present in the data, newest first (drives the month navigator).
    static func months(in transactions: [Transaction]) -> [Date] {
        let firsts = transactions.compactMap { tx -> Date? in
            guard let d = HistoryFormatting.date(tx.createdAt) else { return nil }
            return cal.dateInterval(of: .month, for: d)?.start
        }
        return Array(Set(firsts)).sorted(by: >)
    }

    static func monthTransactions(_ transactions: [Transaction], inMonthOf monthStart: Date) -> [Transaction] {
        guard let interval = cal.dateInterval(of: .month, for: monthStart) else { return [] }
        return transactions.filter {
            guard let d = HistoryFormatting.date($0.createdAt) else { return false }
            return interval.contains(d)
        }
    }

    /// Category slices for one scope within one month, largest first. `resolve` maps each operation to
    /// its (possibly overridden / custom) category — pass ``HistoryStore/category(for:)`` so analytics
    /// honors re-categorized operations and user-defined categories (§10.7).
    static func slices(_ transactions: [Transaction], scope: AnalyticsScope, monthStart: Date?,
                       resolve: (Transaction) -> CategoryRef) -> [CategorySlice] {
        var pool = monthStart.map { monthTransactions(transactions, inMonthOf: $0) } ?? transactions
        switch scope {
        case .expense: pool = pool.filter { $0.amount < 0 }
        case .income:  pool = pool.filter { $0.amount > 0 }
        case .all:     break
        }

        var sums: [String: (ref: CategoryRef, amount: Double, count: Int)] = [:]
        for tx in pool {
            let ref = resolve(tx)
            let entry = sums[ref.id] ?? (ref, 0, 0)
            sums[ref.id] = (ref, entry.amount + abs(tx.amount), entry.count + 1)
        }
        return sums.values
            .map { CategorySlice(category: $0.ref, amount: $0.amount, count: $0.count) }
            .sorted { $0.amount > $1.amount }
    }

    static func total(_ slices: [CategorySlice]) -> Double {
        slices.reduce(0) { $0 + $1.amount }
    }

    /// Income vs. expense per month, oldest → newest (left → right on the bar chart).
    static func monthlySummaries(_ transactions: [Transaction]) -> [MonthlySummary] {
        var buckets: [String: (date: Date, income: Double, expense: Double)] = [:]
        for tx in transactions {
            guard let d = HistoryFormatting.date(tx.createdAt),
                  let start = cal.dateInterval(of: .month, for: d)?.start else { continue }
            let key = monthKey(start)
            var b = buckets[key] ?? (start, 0, 0)
            if tx.amount >= 0 { b.income += tx.amount } else { b.expense += abs(tx.amount) }
            buckets[key] = b
        }
        return buckets
            .map { MonthlySummary(monthKey: $0.key, date: $0.value.date,
                                  income: $0.value.income, expense: $0.value.expense) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Feed grouping

    /// Group transactions into day sections, newest day first. `reference` anchors the relative
    /// «Сегодня / Вчера» labels (the feed passes the newest transaction's date).
    static func daySections(_ transactions: [Transaction], reference: Date) -> [DaySection] {
        var buckets: [Date: [Transaction]] = [:]
        for tx in transactions {
            guard let d = HistoryFormatting.date(tx.createdAt) else { continue }
            let day = cal.startOfDay(for: d)
            buckets[day, default: []].append(tx)
        }
        return buckets.keys.sorted(by: >).map { day in
            let txs = (buckets[day] ?? []).sorted {
                (HistoryFormatting.date($0.createdAt) ?? .distantPast)
                    > (HistoryFormatting.date($1.createdAt) ?? .distantPast)
            }
            return DaySection(
                id: dayKey(day),
                date: day,
                title: HistoryFormatting.dayHeader(for: day, reference: reference),
                net: txs.reduce(0) { $0 + $1.amount },
                transactions: txs
            )
        }
    }

    /// The newest transaction date — the feed's «now» anchor (falls back to `nil` when empty).
    static func referenceDate(_ transactions: [Transaction]) -> Date? {
        transactions.compactMap { HistoryFormatting.date($0.createdAt) }.max()
    }

    // MARK: AI insights (static / demo)

    /// A couple of deterministic insight cards for the selected month + scope. Computed from the
    /// fixtures so they look smart, but explicitly demo until Фаза 3 (§10.9).
    static func insights(for transactions: [Transaction], scope: AnalyticsScope, monthStart: Date?,
                         resolve: (Transaction) -> CategoryRef) -> [AIInsight] {
        guard let monthStart else { return [] }
        let monthTx = monthTransactions(transactions, inMonthOf: monthStart)
        let expenseSlices = slices(monthTx, scope: .expense, monthStart: nil, resolve: resolve)
        let spent = total(expenseSlices)
        let income = monthTx.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }

        var out: [AIInsight] = []

        // Forecast: project month-end spend from the elapsed fraction of the month.
        if spent > 0, let interval = cal.dateInterval(of: .month, for: monthStart) {
            let ref = referenceDate(monthTx) ?? interval.start
            let elapsed: Double = max(ref.timeIntervalSince(interval.start), 1)
            let fraction: Double = min(max(elapsed / interval.duration, 0.05), 1)
            let projected = spent / fraction
            out.append(AIInsight(
                kind: .forecast,
                title: "Прогноз к концу месяца",
                message: "При текущем темпе расходы составят ≈ \(rub(projected)). "
                       + "Сейчас потрачено \(rub(spent)) (\(Int(fraction * 100))% месяца)."
            ))
        }

        // Anomaly: the dominant expense category framed as a watch-item.
        if let top = expenseSlices.first, spent > 0 {
            let share = Int((top.amount / spent * 100).rounded())
            out.append(AIInsight(
                kind: .anomaly,
                title: "Крупнейшая категория",
                message: "«\(top.category.title)» — \(rub(top.amount)) (\(share)% расходов). "
                       + "Похожие подписки и покупки растут ~+40% к прошлому месяцу."
            ))
        }

        // Tip: savings rate.
        if income > 0 {
            let saved = income - spent
            let rate = Int((saved / income * 100).rounded())
            out.append(AIInsight(
                kind: .tip,
                title: saved >= 0 ? "Норма сбережений" : "Перерасход",
                message: saved >= 0
                    ? "Вы отложили \(rub(saved)) — это \(rate)% доходов за месяц."
                    : "Расходы превысили доходы на \(rub(-saved)). Стоит пересмотреть бюджет."
            ))
        }

        return out
    }

    // MARK: Helpers

    private static func monthKey(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
    private static func dayKey(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static let rubFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"
        f.maximumFractionDigits = 0
        return f
    }()
    private static func rub(_ value: Double) -> String {
        let n = rubFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(n) ₽"
    }
}
