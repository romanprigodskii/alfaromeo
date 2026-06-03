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
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    card
                    Text(disclaimer)
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.lg)
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
        ? "Демо-адрес. Реальный адрес для приёма выдаёт крипто-модуль с выбором сети (§10.8)."
        : "Демо-данные. Не настоящие банковские реквизиты — для пополнения переводом по реквизитам."
    }

    private var card: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label(accountTitle,
                          systemImage: requisites.isCrypto ? "bitcoinsign.circle" : "building.columns")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Spacer()
                    revealButton
                }

                if requisites.isCrypto {
                    valueRow("Адрес кошелька",
                             revealed ? requisites.address : requisites.addressMasked,
                             copyable: revealed ? requisites.address : nil, mono: true)
                    divider
                    valueRow("Сеть", requisites.network, copyable: nil, mono: false)
                } else {
                    valueRow("Номер счёта",
                             revealed ? requisites.accountNumberFull : requisites.accountNumberMasked,
                             copyable: revealed ? plain(requisites.accountNumberFull) : nil, mono: true)
                    divider
                    valueRow("Банк", requisites.bankName, copyable: nil, mono: false)
                    divider
                    valueRow("БИК", requisites.bik, copyable: requisites.bik, mono: true)
                    divider
                    valueRow("Корр. счёт", requisites.corrAccount, copyable: plain(requisites.corrAccount), mono: true)
                    divider
                    valueRow("Получатель", requisites.holder, copyable: requisites.holder, mono: false)
                    divider
                    valueRow("ИНН", requisites.inn, copyable: requisites.inn, mono: true)
                }
            }
        }
    }

    private var divider: some View { Divider().overlay(theme.border) }

    private var revealButton: some View {
        Button { withAnimation(Motion.snappy) { revealed.toggle() } } label: {
            Image(systemName: revealed ? "eye.slash" : "eye")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 36, height: 36)
                .background(theme.elevated, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(revealed ? "Скрыть реквизиты" : "Показать реквизиты")
    }

    private func valueRow(_ label: String, _ value: String, copyable: String?, mono: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            HStack(spacing: Spacing.sm) {
                Text(value)
                    .font(mono ? BrandFont.mono(16, weight: .medium) : BrandFont.bodyM)
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                if let copyable { copyButton(label: label, value: copyable) }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder private func copyButton(label: String, value: String) -> some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = value
            #endif
            withAnimation(Motion.snappy) { copied = label }
        } label: {
            Image(systemName: copied == label ? "checkmark" : "doc.on.doc")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(copied == label ? theme.success : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Скопировать \(label)")
    }

    /// Strip thin-space grouping so the copied value is a clean digit run.
    private func plain(_ s: String) -> String {
        s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{2009}", with: "")
    }
}
