import SwiftUI

/// Платежи поставщикам (§9.2): поиск поставщика + категории. Filtering by category chip and a free
/// search; selecting a supplier opens the prefilled payment flow.
struct SuppliersView: View {
    @Environment(Router.self) private var router
    @Environment(\.theme) private var theme

    @State private var query = ""
    @State private var categoryId: String?

    private let categories = PaymentsMockData.supplierCategories

    private var results: [Biller] {
        var list = PaymentsMockData.suppliers
        if let categoryId { list = list.filter { $0.categoryId == categoryId } }
        if !query.isEmpty {
            let q = query.lowercased()
            list = list.filter { $0.name.lowercased().contains(q) || $0.detail.lowercased().contains(q) }
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                searchField
                categoryChips
                resultsSection
                    .padding(.top, Spacing.sm)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Поставщики")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.snappy, value: categoryId)
        .animation(Motion.snappy, value: query)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
            TextField("Поставщик, ИНН или услуга", text: $query)
                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 48)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(categories) { category in
                    let selected = categoryId == category.id
                    Button {
                        categoryId = selected ? nil : category.id
                    } label: {
                        Text(category.name)
                            .font(BrandFont.subheadline)
                            .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                            .padding(.horizontal, Spacing.md - 4)
                            .frame(minHeight: 36)
                            .background(selected ? theme.accent : theme.surface,
                                        in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private var resultsSection: some View {
        GroupedSection {
            if results.isEmpty {
                Text("Ничего не найдено")
                    .font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            } else {
                ForEach(results) { biller in
                    Button { router.push(PaymentsRoute.payBiller(billerId: biller.id)) } label: {
                        ListRow(icon: biller.icon, title: biller.name,
                                subtitle: biller.detail, showsChevron: true)
                    }
                    .buttonStyle(.row)
                }
            }
        }
    }
}
