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

            GroupedSection {
                if filtered.isEmpty {
                    Text("Контакт не найден")
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
                } else {
                    ForEach(filtered) { contact in
                        Button { onSelect(contact) } label: { row(contact) }
                            .buttonStyle(.row)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.textSecondary)
            TextField("Имя или телефон", text: $query)
                .font(BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 48)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    private func row(_ contact: PaymentContact) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            Avatar(initials: contact.initials, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(secondary(contact)).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
            }
            Spacer(minLength: Spacing.sm)
            if showsWalletHint && !contact.hasWallet {
                Badge(kind: .text("Инвайт"))
            }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    private func secondary(_ contact: PaymentContact) -> String {
        let phone = Self.displayPhone(contact.phone)
        if showsWalletHint {
            return contact.hasWallet ? "\(phone) · \(contact.walletShort ?? "кошелёк")" : "\(phone) · без кошелька"
        }
        return "\(phone) · \(contact.bank)"
    }

    /// «+79129257878» → «+7 912 925-78-78»; anything that isn't a Russian 11-digit number passes through.
    static func displayPhone(_ raw: String) -> String {
        let d = Array(raw.filter(\.isNumber))
        guard d.count == 11, d[0] == "7" || d[0] == "8" else { return raw }
        let s = { (r: Range<Int>) in String(d[r]) }
        return "+7\u{00A0}\(s(1..<4))\u{00A0}\(s(4..<7))-\(s(7..<9))-\(s(9..<11))"
    }
}

#Preview {
    ScrollView {
        ContactPickerList(contacts: PaymentsMockData.contacts, showsWalletHint: true) { _ in }
            .padding(Spacing.screen)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
