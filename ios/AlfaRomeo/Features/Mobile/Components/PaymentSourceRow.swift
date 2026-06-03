import SwiftUI

/// Выбор счёта списания (§7.1 «с любого счёта (вкл. крипту)»). One ``PaymentSource`` — fiat / цифр.₽
/// account or crypto wallet — selectable. Crypto sources get the cold-gradient accent + a «Крипта» tag.
struct PaymentSourceRow: View {
    let source: PaymentSource
    let isSelected: Bool
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    private var tint: Color { source.isCrypto ? (theme.accentCrypto.first ?? theme.accent) : theme.accent }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                Image(systemName: source.icon)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(source.title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        if source.isCrypto { Badge(kind: .text("Крипта"), tint: tint) }
                    }
                    Text(source.balanceLabel).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(isSelected ? theme.accent : theme.border)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
