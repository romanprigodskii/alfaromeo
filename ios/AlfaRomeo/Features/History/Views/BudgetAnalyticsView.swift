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
                        title: selectedMonth.map(HistoryFormatting.monthYear) ?? "",
                        canGoPrev: monthIndex < months.count - 1,
                        canGoNext: monthIndex > 0,
                        onPrev: { if monthIndex < months.count - 1 { monthIndex += 1 } },
                        onNext: { if monthIndex > 0 { monthIndex -= 1 } }
                    )
                }

                if !loaded {
                    // Skeleton rows instead of a centred spinner (docs/DESIGN.md §5).
                    GroupedSection {
                        ForEach(0..<5, id: \.self) { _ in SkeletonRow() }
                    }
                } else {
                    scopeContent
                    insightsSection
                    footerLinks
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
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
        GroupedSection("Категории") {
            ForEach(slices) { slice in
                categoryRow(slice)
            }
        }
    }

    /// Monochrome glyph, title and amount; below, the count and share, then a bar in the category's
    /// chart colour so the list doubles as the donut's legend.
    private func categoryRow(_ slice: CategorySlice) -> some View {
        let share = slice.percent(of: total)
        return HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: slice.category.icon, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(slice.category.title)
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    AmountText(amount: slice.amount, size: 17)
                        .fixedSize()
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(HistoryFormatting.operations(slice.count))
                    Spacer(minLength: Spacing.sm)
                    Text(MoneyFormat.percent(share * 100, maxFractionDigits: 0))
                        .monospacedDigit()
                }
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                ProgressBar(value: share, tint: slice.category.tint, height: 4)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
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
            GroupedSection("Итого") {
                summaryRow("Доходы", income, colorBySign: true)
                summaryRow("Расходы", expense)
                summaryRow("Сбережения", income - expense, showsSign: true, colorBySign: true)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: Double,
                            showsSign: Bool = false, colorBySign: Bool = false) -> some View {
        HStack {
            Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
            Spacer()
            AmountText(amount: value, size: 17, showsSign: showsSign, colorBySign: colorBySign)
        }
        .frame(minHeight: Spacing.rowMinHeight)
    }

    @ViewBuilder
    private var insightsSection: some View {
        if !insights.isEmpty {
            GroupedSection("Подсказки", footer: "Демо: подсказки AI рассчитаны по вашим операциям на устройстве.") {
                ForEach(insights) { AIInsightCard(insight: $0) }
            }
        }
    }

    private var footerLinks: some View {
        GroupedSection {
            linkRow(icon: "square.and.arrow.up", title: "Отчёты и экспорт", subtitle: "PDF и CSV") {
                router.push(HistoryRoute.reports)
            }
            linkRow(icon: "square.grid.2x2", title: "Мои категории", subtitle: nil) {
                router.push(HistoryRoute.categories)
            }
            linkRow(icon: "plus", title: "Добавить расход", subtitle: "Ручной учёт") {
                router.push(HistoryRoute.addExpense)
            }
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, subtitle: subtitle, showsChevron: true)
        }
        .buttonStyle(.row)
    }

    private var emptyMonth: some View {
        VStack(spacing: Spacing.sm) {
            GlyphCircle(systemImage: "chart.pie", size: 56)
            Text("Нет данных за этот месяц")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Выберите другой месяц или вкладку.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Spacing.xxl)
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
