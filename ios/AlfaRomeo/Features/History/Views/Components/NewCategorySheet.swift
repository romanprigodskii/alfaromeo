import SwiftUI

/// Create a custom category (§9.4 «добавить категорию»): name + icon + color. On save it's persisted
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
                    .font(BrandFont.title).foregroundStyle(theme.textPrimary)

                preview

                field("Название") {
                    TextField("Например, Питомцы", text: $title)
                        .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                }

                section("Иконка") {
                    LazyVGrid(columns: iconColumns, spacing: Spacing.sm) {
                        ForEach(Self.icons, id: \.self) { name in
                            iconCell(name)
                        }
                    }
                }

                section("Цвет") {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Self.palette, id: \.self) { hex in
                            colorCell(hex)
                        }
                    }
                }

                PrimaryButton(title: "Создать категорию", icon: "checkmark") {
                    let created = store.addCustomCategory(title: trimmed, icon: icon, tintHex: tintHex)
                    onCreate(created)
                    dismiss()
                }
                .disabled(trimmed.isEmpty)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: tintHex))
                .frame(width: 52, height: 52)
                .background(Color(hex: tintHex).opacity(0.16),
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            Text(trimmed.isEmpty ? "Без названия" : trimmed)
                .font(BrandFont.headline)
                .foregroundStyle(trimmed.isEmpty ? theme.textSecondary : theme.textPrimary)
            Spacer()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func iconCell(_ name: String) -> some View {
        let selected = name == icon
        return Button { icon = name } label: {
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: tintHex) : theme.textSecondary)
                .frame(width: 52, height: 52)
                .background((selected ? Color(hex: tintHex).opacity(0.16) : theme.surface),
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(selected ? Color(hex: tintHex) : theme.border, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func colorCell(_ hex: UInt32) -> some View {
        let selected = hex == tintHex
        return Button { tintHex = hex } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(theme.textPrimary.opacity(selected ? 0.9 : 0), lineWidth: 2).padding(-3))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                content()
            }
        }
    }

    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label.uppercased()).font(BrandFont.micro).tracking(1).foregroundStyle(theme.textSecondary)
            content()
        }
    }
}
