import SwiftUI

/// Accounts block (§9.1): the profile's ₽ / currency / digital-₽ / crypto accounts as a grouped list
/// with a currency glyph per row. Currency accounts show the курс ЦБ and a ₽ estimate. Tapping a row
/// opens the account detail (``HomeRoute.accountDetail``).
struct AccountsBlock: View {
    let accounts: [Account]
    var onTap: (Account) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection("Счета") {
            ForEach(accounts) { account in
                Button { onTap(account) } label: { row(account) }
                    .buttonStyle(.row)
            }
        }
    }

    private func row(_ account: Account) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(currency: account.type == .digitalRuble ? "DRUB" : account.currency,
                        size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(label(account))
                    .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle(account))
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(amount: account.balance, currency: symbol(account.currency), size: 17)
                if AccountValuation.isForeignFiat(account.currency) {
                    Text("≈ \(MoneyFormat.fiat(FXRateService.shared.rubValue(account.balance, currency: account.currency).rounded()))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }

    /// Currency accounts: the code + its курс ЦБ (`USD · 83,25 ₽`); otherwise the bare code.
    private func subtitle(_ account: Account) -> String {
        guard AccountValuation.isForeignFiat(account.currency) else { return account.currency }
        let fx = FXRateService.shared
        return "\(account.currency) · \(MoneyFormat.fiat(fx.rate(account.currency)))"
    }

    private func label(_ account: Account) -> String {
        switch account.type {
        case .current:      return account.currency == "RUB" ? "Текущий счёт" : "Валютный счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой рубль"
        }
    }

    private func symbol(_ currency: String) -> String { currency == "RUB" ? "₽" : currency }
}
