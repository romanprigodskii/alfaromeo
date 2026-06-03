import SwiftUI

/// Добавить расход (§9.4 «ручной учёт») — manual expense entry. Demo only: the entry isn't persisted
/// (no write path in the contract yet), shown by an honest success pill on save.
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
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        field("Сумма") {
                            HStack {
                                TextField("0", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(BrandFont.amount)
                                    .foregroundStyle(theme.textPrimary)
                                Text("₽").font(BrandFont.amountS).foregroundStyle(theme.textSecondary)
                            }
                        }

                        Divider().overlay(theme.border)

                        Button { showCategoryPicker = true } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(category.tint)
                                    .frame(width: 36, height: 36)
                                    .background(category.tint.opacity(0.16),
                                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Категория").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                                    Text(category.title).font(BrandFont.bodyM.weight(.medium))
                                        .foregroundStyle(theme.textPrimary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(theme.border)

                        field("Куда / описание") {
                            TextField("Например, Пятёрочка", text: $merchant)
                                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        }

                        Divider().overlay(theme.border)

                        DatePicker(selection: $date, displayedComponents: [.date, .hourAndMinute]) {
                            Text("Дата и время").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        }
                        .tint(theme.accent)
                    }
                }

                PrimaryButton(title: "Сохранить расход", icon: "checkmark") { save() }
                    .disabled(!canSave)

                Text("Расход появится в ленте операций и учтётся в аналитике текущей сессии.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.lg)
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
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            content()
        }
    }
}

#Preview {
    NavigationStack { AddExpenseView() }
        .environment(AppSession.mockAuthenticated())
        .environment(Router())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
