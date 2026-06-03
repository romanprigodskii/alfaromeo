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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                searchField
                categoryChips
                resultsCard
            }
            .padding(Spacing.lg)
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
                .font(BrandFont.body()).foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(Spacing.md)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(categories) { category in
                    let selected = categoryId == category.id
                    Button {
                        categoryId = selected ? nil : category.id
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: category.icon).font(.system(size: 13, weight: .semibold))
                            Text(category.name).font(BrandFont.caption.weight(.medium))
                        }
                        .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 38)
                        .background(selected ? theme.accent : theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(selected ? Color.clear : theme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
        .scrollClipDisabled()
    }

    private var resultsCard: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                if results.isEmpty {
                    Text("Ничего не найдено")
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.md)
                } else {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, biller in
                        Button { router.push(PaymentsRoute.payBiller(billerId: biller.id)) } label: {
                            ListRow(icon: biller.icon, title: biller.name,
                                    subtitle: biller.detail, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                        if index < results.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }
}
