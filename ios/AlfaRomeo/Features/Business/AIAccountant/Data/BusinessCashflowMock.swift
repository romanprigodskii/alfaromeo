import Foundation

/// Builds the deterministic 90-day business cash-flow scenario for the AI-бухгалтер (§8.2).
///
/// The scheduled events are tuned so the running balance bottoms out at exactly −1 200 000 ₽ on day 14
/// — the cash gap the cards highlight and the backend digest (`ai.context.ts`) describes as «примерно
/// через 14 дней … около 1,2 млн ₽». The horizon is anchored to *today*, so «через 14 дней» is always
/// relative to the demo's run date; only the client stamps the absolute gap date.
///
/// Mock business cashflow, per §14 ("Мок/симуляция — банковские рельсы") — no live ledger here.
enum BusinessCashflowMock {

    /// Company + starting balance match the backend's `profile-business-demo` (ООО «Ромео», 2 750 000 ₽).
    static let companyName = "ООО «Ромео»"
    static let startBalance: Double = 2_750_000

    /// Scheduled inflows (+) / outflows (−) over the next 90 days. `(dayOffset, amount₽, label)`.
    private static let schedule: [(day: Int, amount: Double, label: String)] = [
        (1,     96_000, "Эквайринг"),
        (3,   -600_000, "Аванс поставщику «МеталлТорг»"),
        (7,   -180_000, "Аренда офиса"),
        (10, -1_450_000, "Оплата поставщику «ПромСнаб»"),
        (12,  -950_000, "НДС + страховые взносы"),
        (14,  -866_000, "Зарплатный реестр"),          // ← trough: balance hits −1 200 000 ₽
        (18,  1_900_000, "Оплата от ООО «Ромашка» (счёт №104)"),
        (22,   140_000, "Эквайринг"),
        (26,  -820_000, "Зарплатный реестр"),
        (30,   900_000, "Оплата от АО «Север» (счёт №108)"),
        (40,  -180_000, "Аренда офиса"),
        (45,  1_250_000, "Оплата от ООО «Ромашка» (счёт №111)"),
        (54,  -820_000, "Зарплатный реестр"),
        (62,   160_000, "Эквайринг"),
        (68,  -180_000, "Аренда офиса"),
        (82,  -820_000, "Зарплатный реестр"),
        (88,   780_000, "Оплата от АО «Север» (счёт №120)"),
    ]

    /// Monthly expense split (auto-classified) — mirrors the backend `topExpenses`.
    private static let expenseSplit: [(label: String, share: Int)] = [
        ("Закупки/поставщики", 42),
        ("Зарплаты (ФОТ)", 28),
        ("Аренда", 12),
        ("Налоги и взносы", 9),
        ("Реклама", 6),
        ("Прочее", 3),
    ]
    private static let monthlyExpenseBase: Double = 4_380_000

    static func scenario(today: Date = Date(), calendar: Calendar = .current) -> CashflowScenario {
        let start = calendar.startOfDay(for: today)
        let day0 = start

        func date(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: day0) ?? day0
        }

        // Project the balance day-by-day (a step series: balance changes on event days, flat between).
        var points: [CashflowPoint] = []
        points.reserveCapacity(91)
        for d in 0...90 {
            let delta = schedule.filter { $0.day <= d }.reduce(0) { $0 + $1.amount }
            points.append(CashflowPoint(day: d, date: date(d), balance: startBalance + delta))
        }

        let events = schedule.map { CashflowEvent(day: $0.day, date: date($0.day), amount: $0.amount, label: $0.label) }

        // Cash gap = the deepest point if the projection ever goes negative.
        let trough = points.min { $0.balance < $1.balance }
        let gap: CashGap? = {
            guard let t = trough, t.balance < 0 else { return nil }
            return CashGap(amount: -t.balance, date: t.date, inDays: t.day)
        }()

        let tax = TaxOptimization(
            current: "УСН «Доходы» 6%",
            suggested: "УСН «Доходы минус расходы» 15%",
            savingPercent: 8,
            savingRubPerYear: 210_000
        )

        let expenses = expenseSplit.map {
            ExpenseCategory(label: $0.label, sharePercent: $0.share, amount: monthlyExpenseBase * Double($0.share) / 100)
        }

        return CashflowScenario(
            companyName: companyName,
            startBalance: startBalance,
            points: points,
            events: events,
            gap: gap,
            tax: tax,
            expenses: expenses,
            unpaidInvoicesCount: 3,
            unpaidInvoicesTotal: 980_000,
            classifiedOpsCount: 128,
            needsReviewCount: 4
        )
    }
}
