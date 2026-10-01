import SwiftUI

/// История — operations feed root (§9.4).
///
/// Lents the active profile's operations grouped by day (§9.4 «группы по датам»), with category icons,
/// signed amounts, statuses, and the filter set «Пополнение / Списание / Даты / Счета». Tapping a row
/// opens the operation detail; the toolbar reaches budget analytics and the manual-accounting / export
/// routes. All data is profile-scoped and reloads on profile switch (§5.3).
struct HistoryView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var filter = HistoryFilter()
    @State private var isLoading = true

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var transactions: [Transaction] { store.allTransactions }
    private var accounts: [Account] { store.accounts }
    private var reference: Date { store.referenceDate ?? Date() }
    private var activityAccounts: [Account] {
        HistoryFilter.accountsWithActivity(accounts, transactions: transactions)
    }
    private var filtered: [Transaction] {
        transactions.filter { filter.matches($0, accounts: accounts, reference: reference) }
    }
    private var sections: [DaySection] {
        BudgetAnalytics.daySections(filtered, reference: reference)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterHeader
            content
        }
        .background(theme.background.ignoresSafeArea())
        .animation(reduceMotion ? nil : Motion.snappy, value: filter)
        .toolbar { toolbarItems }
        .navigationDestination(for: HistoryRoute.self) { $0.destination }
        .task(id: profileId) { await load() }
    }

    // MARK: - Header (filters)

    private var filterHeader: some View {
        VStack(spacing: Spacing.sm) {
            HistorySegmentedControl(
                segments: HistoryFilter.Flow.allCases.map { ($0, $0.title) },
                selection: $filter.flow
            )
            HStack(spacing: Spacing.sm) {
                accountMenu
                dateMenu
                Spacer(minLength: 0)
                if filter.isActive {
                    Button { filter = HistoryFilter() } label: {
                        Text("Сбросить").font(BrandFont.subheadline.weight(.medium))
                            .foregroundStyle(theme.accent)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.sm)
        .padding(.bottom, 12)
        .background(theme.background)
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var accountMenu: some View {
        Menu {
            Picker("Счёт", selection: $filter.accountId) {
                Text("Все счета").tag(nil as String?)
                ForEach(activityAccounts) { account in
                    Text(accountLabel(account)).tag(account.id as String?)
                }
            }
        } label: {
            FilterChip(title: accountChipTitle, isActive: filter.accountId != nil)
        }
        .disabled(activityAccounts.count < 2)
    }

    private var dateMenu: some View {
        Menu {
            Picker("Период", selection: $filter.datePreset) {
                ForEach(HistoryFilter.DatePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
        } label: {
            FilterChip(title: filter.datePreset.chipLabel, isActive: filter.datePreset != .all)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.push(HistoryRoute.budgetAnalytics) } label: {
                Image(systemName: "chart.pie")
            }
            .accessibilityLabel("Аналитика бюджета")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { router.push(HistoryRoute.addExpense) } label: {
                    Label("Добавить расход", systemImage: "plus")
                }
                Button { router.push(HistoryRoute.categories) } label: {
                    Label("Мои категории", systemImage: "square.grid.2x2")
                }
                Button { router.push(HistoryRoute.reports) } label: {
                    Label("Отчёты и экспорт", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Ещё")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            // Skeleton rows instead of a centred spinner (docs/DESIGN.md §5).
            ScrollView {
                GroupedSection {
                    ForEach(0..<6, id: \.self) { _ in SkeletonRow() }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.md)
            }
            .scrollDisabled(true)
        } else if sections.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.md)
            }
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
    }

    /// One day: a quiet date label with the day's net, then the operations as a grouped list.
    private func sectionView(_ section: DaySection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(BrandFont.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                AmountText(amount: section.net, size: 15, showsSign: true, colorBySign: true)
            }
            .padding(.horizontal, Spacing.md)
            GroupedSection {
                ForEach(section.transactions) { tx in
                    Button {
                        router.push(HistoryRoute.operationDetail(txId: tx.id))
                    } label: {
                        TransactionRow(transaction: tx, category: store.category(for: tx))
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            GlyphCircle(systemImage: filter.isActive ? "line.3.horizontal.decrease" : "tray", size: 56)
            Text(filter.isActive ? "Нет операций по фильтру" : "Пока нет операций")
                .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text(filter.isActive
                 ? "Измените период, счёт или тип операций."
                 : "Здесь появятся операции активного профиля.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            if filter.isActive {
                SecondaryButton(title: "Сбросить фильтры") {
                    filter = HistoryFilter()
                }
                .frame(maxWidth: 260)
                .padding(.top, Spacing.sm)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var accountChipTitle: String {
        if let id = filter.accountId, let account = accounts.first(where: { $0.id == id }) {
            return accountLabel(account)
        }
        return "Счета"
    }

    private func accountLabel(_ account: Account) -> String {
        switch account.type {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой ₽"
        }
    }

    private func load() async {
        isLoading = true
        // Reset the filter on (re)entry; the store drops the previous profile's data on switch (§5.3).
        filter = HistoryFilter()
        await store.load(api: api, profileId: profileId)
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .navigationTitle("История")
    }
    .environment(AppSession.mockAuthenticated())
    .environment(Router())
    .environment(\.theme, .default)
    .environment(\.apiClient, MockAPIClient())
}
