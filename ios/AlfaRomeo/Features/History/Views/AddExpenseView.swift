import SwiftUI

/// Добавить расход (§9.4 «ручной учёт»): manual expense entry, kept in ``HistoryStore`` for the
/// session (no write path in the contract yet).
struct AddExpenseView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = HistoryStore.shared
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var category = CategoryRef(.groceries)
    @State private var date = Date()
    @State private var didSeedDate = false
    @State private var showCategoryPicker = false

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var amountValue: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: ""))
    }
    private var canSave: Bool { (amountValue ?? 0) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                GroupedSection(footer: "Расход появится в ленте операций и учтётся в аналитике текущей сессии.") {
                    field("Сумма") {
                        HStack {
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(BrandFont.amount)
                                .foregroundStyle(theme.textPrimary)
                            Text("₽").font(BrandFont.amountS).foregroundStyle(theme.textSecondary)
                        }
                    }

                    Button { showCategoryPicker = true } label: {
                        HStack(spacing: ListRow.glyphSpacing) {
                            GlyphCircle(systemImage: category.icon, size: ListRow.glyphSize)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Категория").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                                Text(category.title).font(BrandFont.bodyM)
                                    .foregroundStyle(theme.textPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.vertical, Spacing.rowVertical)
                        .contentShape(Rectangle())
                        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
                    }
                    .buttonStyle(.row)

                    field("Получатель или описание") {
                        TextField("Например, Пятёрочка", text: $merchant)
                            .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    }

                    DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                        Text("Дата и время").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    }
                    .tint(theme.accent)
                    .frame(minHeight: Spacing.rowMinHeight)
                }

                PrimaryButton(title: "Сохранить расход") { save() }
                    .disabled(!canSave)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Добавить расход")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(selection: $category)
        }
        .task {
            await store.load(api: api, profileId: profileId)
            // Anchor a new expense to the feed's «now» (newest op) so it lands at the top of the
            // future-dated demo timeline instead of under the real wall clock. User can still change it.
            if !didSeedDate { date = store.referenceDate ?? date; didSeedDate = true }
        }
    }

    private func save() {
        guard let amount = amountValue, amount > 0 else { return }
        store.addExpense(amount: amount, category: category, note: merchant, date: date, profileId: profileId)
        router.pop()
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            content()
        }
        .padding(.vertical, Spacing.rowVertical)
    }
}

#Preview {
    NavigationStack { AddExpenseView() }
        .environment(AppSession.mockAuthenticated())
        .environment(Router())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
