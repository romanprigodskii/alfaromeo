import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Account requisites with a show/hide «глаз» and copy-to-clipboard (§9.1), mirroring
/// ``CardRequisitesCard`` (§6.3). Masked by default; revealing flips the number/address and lets the
/// user copy each field. For ₽ accounts shows the banking set (счёт / БИК / корр. счёт / получатель /
/// ИНН); for the crypto account shows the watch-only deposit address + network. Demo values only — the
/// real requisites never live client-side (§11.8). Built from ``AccountRequisites``.
struct AccountRequisitesSheet: View {
    let requisites: AccountRequisites
    let accountTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var revealed = false
    @State private var copied: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                card
                    .padding(.horizontal, Spacing.screen)
                    .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle(requisites.isCrypto ? "Адрес для приёма" : "Реквизиты счёта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }.font(BrandFont.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var disclaimer: String {
        requisites.isCrypto
        ? "Демо-адрес. Настоящий адрес для приёма выдаёт раздел крипты, с выбором сети."
        : "Демо-данные, не настоящие банковские реквизиты. Нужны для пополнения переводом по реквизитам."
    }

    private var card: some View {
        GroupedSection(accountTitle,
                       actionTitle: revealed ? "Скрыть" : "Показать",
                       action: { withAnimation(Motion.snappy) { revealed.toggle() } },
                       footer: disclaimer) {
            if requisites.isCrypto {
                valueRow("Адрес кошелька",
                         revealed ? requisites.address : requisites.addressMasked,
                         copyable: revealed ? requisites.address : nil, code: true)
                valueRow("Сеть", requisites.network, copyable: nil, code: false)
            } else {
                valueRow("Номер счёта",
                         revealed ? requisites.accountNumberFull : requisites.accountNumberMasked,
                         copyable: revealed ? plain(requisites.accountNumberFull) : nil, code: true)
                valueRow("Банк", requisites.bankName, copyable: nil, code: false)
                valueRow("БИК", requisites.bik, copyable: requisites.bik, code: true)
                valueRow("Корр. счёт", requisites.corrAccount, copyable: plain(requisites.corrAccount), code: true)
                valueRow("Получатель", requisites.holder, copyable: requisites.holder, code: false)
                valueRow("ИНН", requisites.inn, copyable: requisites.inn, code: true)
            }
        }
    }

    /// Requisites (счёт, БИК, корр. счёт, ИНН, адрес) in true monospace; names in SF Pro.
    private func valueRow(_ label: String, _ value: String, copyable: String?, code: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(code ? BrandFont.code(16) : BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.sm)
            if let copyable { copyButton(label: label, value: copyable) }
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
    }

    @ViewBuilder private func copyButton(label: String, value: String) -> some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = value
            #endif
            withAnimation(Motion.snappy) { copied = label }
        } label: {
            Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(copied == label ? theme.statusInk(.success) : theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Скопировать \(label)")
    }

    /// Strip thin-space grouping so the copied value is a clean digit run.
    private func plain(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{2009}", with: "")
    }
}
