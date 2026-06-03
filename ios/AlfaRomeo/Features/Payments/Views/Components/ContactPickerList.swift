import SwiftUI

/// Searchable contact list for the СБП and crypto recipient steps (§10.3). Each row shows the
/// avatar initials, name, and either the receiving bank (СБП) or the wallet / invite hint (crypto).
struct ContactPickerList: View {
    let contacts: [PaymentContact]
    var showsWalletHint: Bool = false
    var onSelect: (PaymentContact) -> Void

    @Environment(\.theme) private var theme
    @State private var query = ""

    private var filtered: [PaymentContact] {
        guard !query.isEmpty else { return contacts }
        let q = query.lowercased()
        return contacts.filter {
            $0.name.lowercased().contains(q) || $0.phone.contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            searchField

            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, contact in
                        Button { onSelect(contact) } label: { row(contact) }
                            .buttonStyle(.plain)
                        if index < filtered.count - 1 { Divider().overlay(theme.border) }
                    }
                    if filtered.isEmpty {
                        Text("Контакт не найден")
                            .font(BrandFont.callout)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Spacing.md)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
            TextField("Имя или телефон", text: $query)
                .font(BrandFont.body())
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(Spacing.md)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func row(_ contact: PaymentContact) -> some View {
        HStack(spacing: Spacing.md) {
            Avatar(initials: contact.initials, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Text(secondary(contact)).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if showsWalletHint && !contact.hasWallet {
                Badge(kind: .text("Инвайт"), tint: theme.accent)
            }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
    }

    private func secondary(_ contact: PaymentContact) -> String {
        if showsWalletHint {
            return contact.hasWallet ? "\(contact.phone) · \(contact.walletShort ?? "кошелёк")" : "\(contact.phone) · без кошелька"
        }
        return "\(contact.phone) · \(contact.bank)"
    }
}

#Preview {
    ScrollView {
        ContactPickerList(contacts: PaymentsMockData.contacts, showsWalletHint: true) { _ in }
            .padding(Spacing.lg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
