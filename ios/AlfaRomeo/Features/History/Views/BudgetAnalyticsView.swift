import SwiftUI

/// Аналитика бюджета (§9.4, §10.7): табы Расходы / Доходы / Вся аналитика, диаграмма на Swift Charts,
/// список категорий с %, помесячная навигация и статические AI-инсайты (прогноз/аномалии).
/// Profile-scoped — reloads on profile switch (§5.3).
struct BudgetAnalyticsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var scope: AnalyticsScope = .expense
    @State private var monthIndex = 0
    @State private var loaded = false

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var transactions: [Transaction] { store.allTransactions }
    private var months: [Date] { BudgetAnalytics.months(in: transactions) }
    private var selectedMonth: Date? {
        months.indices.contains(monthIndex) ? months[monthIndex] : months.first
    }
    private var slices: [CategorySlice] {
        BudgetAnalytics.slices(transactions, scope: scope, monthStart: selectedMonth, resolve: store.category(for:))
    }
    private var total: Double { BudgetAnalytics.total(slices) }
    private var summaries: [MonthlySummary] { BudgetAnalytics.monthlySummaries(transactions) }
    private var insightMonth: Date? { scope == .all ? months.first : selectedMonth }
    private var insights: [AIInsight] {
        BudgetAnalytics.insights(for: transactions, scope: scope, monthStart: insightMonth, resolve: store.category(for:))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HistorySegmentedControl(
                    segments: AnalyticsScope.allCases.map { ($0, $0.title) },
                    selection: $scope
                )

                if scope != .all, !months.isEmpty {
                    MonthNavigator(
                        title: selectedMonth.map(HistoryFormatting.monthYear) ?? "—",
                        canGoPrev: monthIndex < months.count - 1,
                        canGoNext: monthIndex > 0,
                        onPrev: { if monthIndex < months.count - 1 { monthIndex += 1 } },
                        onNext: { if monthIndex > 0 { monthIndex -= 1 } }
                    )
                }

                if !loaded {
                    ProgressView().controlSize(.large).tint(theme.accent).padding(.top, Spacing.xxl)
                } else {
                    scopeContent
                    insightsSection
                    footerLinks
                }
            }
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Аналитика бюджета")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(reduceMotion ? nil : Motion.snappy, value: scope)
        .animation(reduceMotion ? nil : Motion.snappy, value: monthIndex)
        .task(id: profileId) { await load() }
    }

    // MARK: - Scope content

    @ViewBuilder
    private var scopeContent: some View {
        switch scope {
        case .expense, .income:
            if slices.isEmpty {
                emptyMonth
            } else {
                SurfaceCard { CategoryDonutChart(slices: slices, total: total, centerCaption: scope.title) }
                categoryList
            }
        case .all:
            allAnalytics
        }
    }

    private var categoryList: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                    categoryRow(slice)
                    if index < slices.count - 1 { Divider().overlay(theme.border) }
                }
            }
        }
    }

    private func categoryRow(_ slice: CategorySlice) -> some View {
        let percent = Int((slice.percent(of: total) * 100).rounded())
        return VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                Image(systemName: slice.category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(slice.category.tint)
                    .frame(width: 36, height: 36)
                    .background(slice.category.tint.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(slice.category.title)
                        .font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text("\(slice.count) \(operationsWord(slice.count))")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    AmountText(amount: slice.amount, size: 15)
                    Text("\(percent)%").font(BrandFont.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            ProgressBar(value: slice.percent(of: total), tint: slice.category.tint, height: 6)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var allAnalytics: some View {
        let income = summaries.reduce(0) { $0 + $1.income }
        let expense = summaries.reduce(0) { $0 + $1.expense }
        return VStack(spacing: Spacing.lg) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Доходы и расходы по месяцам")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    MonthlyBarChart(summaries: summaries)
                }
            }
            SurfaceCard {
                VStack(spacing: Spacing.md) {
                    summaryRow("Доходы", income, color: theme.success)
                    Divider().overlay(theme.border)
                    summaryRow("Расходы", expense, color: theme.danger)
                    Divider().overlay(theme.border)
                    summaryRow("Сбережения", income - expense,
                               color: income - expense >= 0 ? theme.success : theme.danger)
                }
            }
        }
    }

    private func summaryRow(_ title: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer()
            AmountText(amount: value, size: 18).foregroundStyle(color)
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("AI-инсайты").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                ForEach(insights) { AIInsightCard(insight: $0) }
            }
        }
    }

    private var footerLinks: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                linkRow(icon: "square.and.arrow.up", title: "Отчёты и экспорт", subtitle: "PDF / CSV") {
                    router.push(HistoryRoute.reports)
                }
                Divider().overlay(theme.border)
                linkRow(icon: "square.grid.2x2", title: "Мои категории", subtitle: nil) {
                    router.push(HistoryRoute.categories)
                }
                Divider().overlay(theme.border)
                linkRow(icon: "plus", title: "Добавить расход", subtitle: "Ручной учёт") {
                    router.push(HistoryRoute.addExpense)
                }
            }
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, subtitle: subtitle, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    private var emptyMonth: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .light)).foregroundStyle(theme.textSecondary)
            Text("Нет данных за этот месяц")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Выберите другой месяц или вкладку.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
    }

    private func operationsWord(_ n: Int) -> String {
        let rem100 = n % 100, rem10 = n % 10
        if rem100 >= 11 && rem100 <= 14 { return "операций" }
        switch rem10 {
        case 1:        return "операция"
        case 2, 3, 4:  return "операции"
        default:       return "операций"
        }
    }

    private func load() async {
        loaded = false
        monthIndex = 0
        await store.load(api: api, profileId: profileId)
        loaded = true
    }
}

#Preview {
    NavigationStack {
        BudgetAnalyticsView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(Router())
    .environment(\.theme, .default)
    .environment(\.apiClient, MockAPIClient())
}
