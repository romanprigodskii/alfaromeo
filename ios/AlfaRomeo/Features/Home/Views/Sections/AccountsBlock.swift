import SwiftUI

/// Accounts block (§9.1): the profile's ₽ / digital-₽ / crypto accounts. Tapping a row opens the
/// account detail stub (``HomeRoute.accountDetail``).
struct AccountsBlock: View {
    let accounts: [Account]
    var onTap: (Account) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        DashboardSection(title: "Счета") {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                        Button { onTap(account) } label: { row(account) }
                            .buttonStyle(.plain)
                        if index < accounts.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    private func row(_ account: Account) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon(account.type))
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.accent.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label(account.type)).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Text(account.currency).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            AmountText(amount: account.balance, currency: symbol(account.currency), size: 17)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private func icon(_ type: AccountType) -> String {
        switch type {
        case .current:      return "rublesign.circle.fill"
        case .savings:      return "banknote.fill"
        case .crypto:       return "bitcoinsign.circle.fill"
        case .digitalRuble: return "r.circle.fill"
        }
    }

    private func label(_ type: AccountType) -> String {
        switch type {
        case .current:      return "Текущий счёт"
        case .savings:      return "Накопительный"
        case .crypto:       return "Крипто-счёт"
        case .digitalRuble: return "Цифровой рубль"
        }
    }

    private func symbol(_ currency: String) -> String { currency == "RUB" ? "₽" : currency }
}
