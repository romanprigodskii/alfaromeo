import SwiftUI

/// Мои категории (§9.4): the category catalog with per-category activity for the active profile.
/// Custom categories persist in ``HistoryStore``. Profile-scoped (§5.3).
struct CategoriesView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var showNewCategory = false
    @State private var createdCategory: CustomCategory?

    private var profileId: String { session.activeProfile?.id ?? "" }

    /// (category, count, total magnitude) for every category — built-ins and the user's own — most-used
    /// first then alphabetical. Counts honor overrides / custom assignments via the store resolver.
    private var rows: [(category: CategoryRef, count: Int, total: Double)] {
        var sums: [String: (Int, Double)] = [:]
        for tx in store.allTransactions {
            let ref = store.category(for: tx)
            let entry = sums[ref.id] ?? (0, 0)
            sums[ref.id] = (entry.0 + 1, entry.1 + abs(tx.amount))
        }
        return store.allCategories
            .map { ($0, sums[$0.id]?.0 ?? 0, sums[$0.id]?.1 ?? 0) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title < rhs.0.title
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GroupedSection(footer: "Категории применяются к операциям автоматически. Свои категории доступны при выборе категории операции и расхода.") {
                    ForEach(rows, id: \.category.id) { row in
                        ListRow(
                            icon: row.category.icon,
                            title: row.category.title,
                            subtitle: subtitle(for: row),
                            value: row.total > 0 ? MoneyFormat.fiat(row.total.rounded()) : nil
                        )
                    }
                }

                PrimaryButton(title: "Добавить категорию") { showNewCategory = true }
                if let created = createdCategory {
                    StatusPill(status: .success, text: "«\(created.title)» добавлена")
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Мои категории")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(reduceMotion ? nil : Motion.snappy, value: createdCategory)
        .sheet(isPresented: $showNewCategory) {
            NewCategorySheet { created in
                withAnimation(reduceMotion ? nil : Motion.snappy) { createdCategory = created }
            }
        }
        .task(id: profileId) { await load() }
    }

    private func subtitle(for row: (category: CategoryRef, count: Int, total: Double)) -> String {
        let usage = row.count > 0 ? HistoryFormatting.operations(row.count) : "Нет операций"
        return row.category.isCustom ? "Своя, \(usage.lowercased())" : usage
    }

    private func load() async {
        await store.load(api: api, profileId: profileId)
    }
}

#Preview {
    NavigationStack { CategoriesView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
