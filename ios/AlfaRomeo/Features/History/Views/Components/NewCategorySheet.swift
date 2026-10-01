import SwiftUI

/// Create a custom category (§9.4 «добавить категорию»): name, icon and chart colour. On save it's persisted
/// in ``HistoryStore`` and becomes available wherever categories are picked (operation detail / add
/// expense) and in the «Мои категории» catalog.
struct NewCategorySheet: View {
    /// Called with the created category so the caller can surface a confirmation.
    var onCreate: (CustomCategory) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = HistoryStore.shared

    @State private var title = ""
    @State private var icon = icons[0]
    @State private var tintHex = palette[0]

    private static let icons = [
        "tag.fill", "cart.fill", "house.fill", "pawprint.fill", "heart.fill", "book.fill",
        "airplane", "gift.fill", "cross.case.fill", "graduationcap.fill", "wrench.and.screwdriver.fill",
        "leaf.fill", "figure.run", "tshirt.fill", "fuelpump.fill", "creditcard.fill",
    ]
    private static let palette: [UInt32] = [
        0xE2120F, 0xFF9F0A, 0xFFD426, 0x34C759, 0x30D5C8, 0x32ADE6, 0x5E7CFF, 0xBF5AF2, 0xFF6482, 0x9AA2B1,
    ]

    private let iconColumns = [GridItem(.adaptive(minimum: 52), spacing: Spacing.sm)]
    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Новая категория")
                    .font(BrandFont.title1).foregroundStyle(theme.textPrimary)

                GroupedSection(footer: "Цвет обозначает категорию на диаграммах аналитики.") {
                    HStack(spacing: ListRow.glyphSpacing) {
                        GlyphCircle(systemImage: icon, size: ListRow.glyphSize)
                        TextField("Название, например Питомцы", text: $title)
                            .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        Circle().fill(Color(hex: tintHex)).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Spacing.rowMinHeight)
                    .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Иконка")
                    LazyVGrid(columns: iconColumns, spacing: Spacing.sm) {
                        ForEach(Self.icons, id: \.self) { name in
                            iconCell(name)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Цвет")
                    HStack(spacing: 0) {
                        ForEach(Self.palette, id: \.self) { hex in
                            colorCell(hex).frame(maxWidth: .infinity)
                        }
                    }
                }

                PrimaryButton(title: "Создать категорию") {
                    let created = store.addCustomCategory(title: trimmed, icon: icon, tintHex: tintHex)
                    onCreate(created)
                    dismiss()
                }
                .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func iconCell(_ name: String) -> some View {
        let selected = name == icon
        return Button { icon = name } label: {
            Image(systemName: GlyphCircle.outlineSymbol(name))
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(selected ? theme.onAccent : theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(selected ? theme.accent : theme.surface,
                            in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func colorCell(_ hex: UInt32) -> some View {
        let selected = hex == tintHex
        return Button { tintHex = hex } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(theme.textPrimary.opacity(selected ? 0.9 : 0), lineWidth: 2).padding(-4))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
