import SwiftUI

/// Мои категории (§9.4) — the category catalog with per-category activity for the active profile.
/// Adding/editing categories is a demo stub (no persistence layer yet). Profile-scoped (§5.3).
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
                Text("Категории применяются к операциям автоматически (§10.7). Свои категории доступны при выборе категории операции и расхода.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)

                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.category.id) { index, row in
                            ListRow(
                                icon: row.category.icon,
                                iconTint: row.category.tint,
                                title: row.category.title,
                                subtitle: subtitle(for: row),
                                value: row.total > 0 ? amount(row.total) : nil
                            )
                            if index < rows.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }

                PrimaryButton(title: "Добавить категорию", icon: "plus") { showNewCategory = true }
                if let created = createdCategory {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: created.iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: created.tintHex))
                        StatusPill(status: .success, text: "«\(created.title)» добавлена")
                    }
                }
            }
            .padding(Spacing.lg)
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
        if row.category.isCustom {
            return row.count > 0 ? "\(row.count) · использований · своя" : "Своя категория"
        }
        return row.count > 0 ? "\(row.count) · использований" : "Нет операций"
    }

    private func amount(_ value: Double) -> String {
        let n = Self.formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(n) ₽"
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"
        f.maximumFractionDigits = 0
        return f
    }()

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
