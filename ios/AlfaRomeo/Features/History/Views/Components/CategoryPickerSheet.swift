import SwiftUI

/// Editable-category picker for the operation detail screen (§9.4 «категория (редактируемая)»).
/// A plain grouped list (monochrome glyph, title, accent checkmark on the current one); tapping a
/// category writes the binding and dismisses. The change is session-local (the contract has no
/// `category` field yet).
struct CategoryPickerSheet: View {
    @Binding var selection: CategoryRef

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = HistoryStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Категория операции")
                    .font(BrandFont.title1)
                    .foregroundStyle(theme.textPrimary)

                GroupedSection {
                    ForEach(store.allCategories) { category in
                        let isSelected = category == selection
                        Button {
                            selection = category
                            dismiss()
                        } label: {
                            HStack(spacing: ListRow.glyphSpacing) {
                                GlyphCircle(systemImage: category.icon, size: ListRow.glyphSize)
                                Text(category.title)
                                    .font(BrandFont.bodyM)
                                    .foregroundStyle(theme.textPrimary)
                                Spacer(minLength: Spacing.sm)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.accent)
                                }
                            }
                            .frame(minHeight: Spacing.rowMinHeight)
                            .contentShape(Rectangle())
                            .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
                        }
                        .buttonStyle(.row)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.background)
    }
}

#Preview {
    struct Host: View {
        @State private var category = CategoryRef(.groceries)
        var body: some View {
            Color.clear.sheet(isPresented: .constant(true)) {
                CategoryPickerSheet(selection: $category)
                    .environment(\.theme, .default)
            }
        }
    }
    return Host()
}
