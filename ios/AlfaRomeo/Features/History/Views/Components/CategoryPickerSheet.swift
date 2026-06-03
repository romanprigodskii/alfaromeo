import SwiftUI

/// Editable-category picker for the operation detail screen (§9.4 «категория (редактируемая)»).
/// Presented as a themed sheet; tapping a category writes the binding and dismisses. The change is
/// session-local (the contract has no `category` field yet) — labeled honestly by the caller.
struct CategoryPickerSheet: View {
    @Binding var selection: CategoryRef

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = HistoryStore.shared

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Категория операции")
                .font(BrandFont.title)
                .foregroundStyle(theme.textPrimary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.sm) {
                    ForEach(store.allCategories) { category in
                        let isSelected = category == selection
                        Button {
                            selection = category
                            dismiss()
                        } label: {
                            VStack(spacing: Spacing.xs) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(category.tint)
                                    .frame(width: 44, height: 44)
                                    .background(category.tint.opacity(0.16),
                                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                Text(category.title)
                                    .font(BrandFont.micro)
                                    .foregroundStyle(theme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.sm)
                            .background(
                                (isSelected ? theme.accent.opacity(0.14) : theme.surface),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .stroke(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .padding(Spacing.lg)
                    .environment(\.theme, .default)
            }
        }
    }
    return Host()
}
