import SwiftUI

/// "Откуда" selector for the amount step: a tappable row showing the chosen source (account or
/// wallet) and its balance, with a native menu to switch. Generic over the option payload so it
/// serves both fiat accounts and crypto wallets (§10.3).
struct SourceAccountPicker: View {
    struct Option: Identifiable, Hashable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let balanceText: String
    }

    var label: String = "Откуда"
    let selectedId: String
    let options: [Option]
    var onSelect: (String) -> Void

    @Environment(\.theme) private var theme

    private var selected: Option? { options.first { $0.id == selectedId } }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    onSelect(option.id)
                } label: {
                    Label("\(option.title) · \(option.balanceText)", systemImage: option.icon)
                }
            }
        } label: {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: selected?.icon ?? "banknote")
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    Text(selected?.title ?? "Не выбран").font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                }
                Spacer(minLength: Spacing.sm)
                Text(selected?.balanceText ?? "")
                    .font(BrandFont.bodyM).monospacedDigit().foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if options.count > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeightTwoLine)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .disabled(options.count <= 1)
    }
}

#Preview {
    SourceAccountPicker(
        selectedId: "a",
        options: [
            .init(id: "a", icon: "banknote.fill", title: "Текущий счёт", subtitle: "·· 4921", balanceText: "184\u{00A0}200\u{00A0}₽"),
            .init(id: "b", icon: "chart.line.uptrend.xyaxis", title: "Накопительный", subtitle: "·· 7711", balanceText: "920\u{00A0}000\u{00A0}₽"),
        ],
        onSelect: { _ in }
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
