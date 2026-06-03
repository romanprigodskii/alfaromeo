import SwiftUI

/// "Откуда" selector for the amount step — a tappable row showing the chosen source (account or
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
            HStack(spacing: Spacing.md) {
                Image(systemName: selected?.icon ?? "banknote.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased()).font(BrandFont.micro).tracking(1).foregroundStyle(theme.textSecondary)
                    Text(selected?.title ?? "—").font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                }
                Spacer(minLength: Spacing.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(selected?.balanceText ?? "")
                        .font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    if options.count > 1 {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .disabled(options.count <= 1)
    }
}

#Preview {
    SourceAccountPicker(
        selectedId: "a",
        options: [
            .init(id: "a", icon: "banknote.fill", title: "Текущий счёт", subtitle: "·· 4921", balanceText: "184 200 ₽"),
            .init(id: "b", icon: "chart.line.uptrend.xyaxis", title: "Накопительный", subtitle: "·· 7711", balanceText: "920 000 ₽"),
        ],
        onSelect: { _ in }
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
