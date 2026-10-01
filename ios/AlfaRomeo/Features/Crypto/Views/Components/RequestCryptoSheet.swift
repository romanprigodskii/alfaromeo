import SwiftUI

/// «Запросить крипту у контакта» (§9.6 «Принять» → запросить). Pick a contact + amount → form a request
/// (simulation) → show a confirmation. No money moves; the request is a payment ask the contact can
/// fulfil into the user's receive address. Self-contained — no backend, no portfolio mutation.
struct RequestCryptoSheet: View {
    let asset: String
    let address: String
    /// Called once the request is "sent", so the host can reflect it (e.g. mark the button done).
    var onSent: (PaymentContact, Double) -> Void = { _, _ in }

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selected: PaymentContact?
    @State private var amountText = ""
    @State private var sent = false

    private var amount: Double { CryptoFormat.parse(amountText) }
    private var canSend: Bool { selected != nil && amount > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if sent, let contact = selected {
                    confirmation(contact)
                } else {
                    form
                }
            }
            .padding(Spacing.screen)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Запросить \(asset)").font(BrandFont.title1).foregroundStyle(theme.textPrimary)

            Text("Контакт").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(PaymentsMockData.contacts) { contact in
                        chip(contact)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()

            AmountEntry(text: $amountText, symbol: asset,
                        secondary: "Сумма к запросу", secondaryIsWarning: false)

            PrimaryButton(title: selected.map { "Запросить у \($0.name.split(separator: " ").first.map(String.init) ?? $0.name)" } ?? "Запросить") {
                guard let contact = selected, amount > 0 else { return }
                withAnimation { sent = true }
                onSent(contact, amount)
            }
            .disabled(!canSend)

            Text("Это запрос на оплату, деньги не списываются. Контакт получит ваш адрес для перевода.")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ contact: PaymentContact) -> some View {
        let isOn = selected?.id == contact.id
        return Button { selected = contact } label: {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle().fill(isOn ? theme.textPrimary : theme.fill)
                        .frame(width: 52, height: 52)
                    Text(contact.initials).font(BrandFont.headline).foregroundStyle(isOn ? theme.background : theme.textPrimary)
                }
                Text(contact.name.split(separator: " ").first.map(String.init) ?? contact.name)
                    .font(BrandFont.footnote).foregroundStyle(isOn ? theme.textPrimary : theme.textSecondary).lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Confirmation

    private func confirmation(_ contact: PaymentContact) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(theme.success)

            VStack(spacing: Spacing.xs) {
                Text("Запрос отправлен").font(BrandFont.title1).foregroundStyle(theme.textPrimary)
                Text("\(contact.name) получит запрос на \(CryptoFormat.qty(amount, symbol: asset)).")
                    .font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }

            GroupedSection {
                requestRow("Кому", contact.name)
                requestRow("Сумма", CryptoFormat.qty(amount, symbol: asset))
                requestRow("На адрес", shortAddress, code: true)
            }

            Text("Контакт сможет отправить \(asset) на ваш адрес одним тапом. Зачисление после подтверждения сети.")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Готово") { dismiss() }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }

    private func requestRow(_ label: String, _ value: String, code: Bool = false) -> some View {
        HStack {
            Text(label).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(code ? BrandFont.code(15) : BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.rowVertical)
    }

    private var shortAddress: String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
