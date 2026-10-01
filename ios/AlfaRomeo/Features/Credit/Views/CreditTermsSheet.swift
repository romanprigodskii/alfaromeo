import SwiftUI

/// «Индивидуальные условия договора» (§10.5): the key terms of the application being signed, built
/// from the wizard's draft (сумма, срок, ставка, платёж), plus the standard repayment clauses. Demo
/// terms, not an offer.
struct CreditTermsSheet: View {
    let productName: String
    let amountNoun: String
    let amount: Double
    let termMonths: Int
    let rateText: String
    let monthlyPayment: Double
    let overpay: Double
    let onAccept: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    GroupedSection("Основные условия") {
                        ListRow(title: "Продукт", value: productName)
                        ListRow(title: amountNoun, value: CreditFormat.rub(amount))
                        ListRow(title: "Срок", value: CreditFormat.term(termMonths))
                        ListRow(title: "Ставка", value: rateText)
                        ListRow(title: "Платёж в месяц", value: CreditFormat.rub(monthlyPayment))
                        ListRow(title: "Переплата", value: CreditFormat.rub(overpay))
                        ListRow(title: "Всего к возврату", value: CreditFormat.rub(amount + overpay))
                    }
                    GroupedSection("Погашение", footer: "Демо-условия, не оферта банка.") {
                        clause("Ежемесячно, равными платежами, в день выдачи кредита.")
                        clause("Досрочное погашение, полное или частичное, без комиссии.")
                        clause("Неустойка при просрочке: 0,05% от суммы просрочки за каждый день.")
                        clause("Отказаться от кредита можно в течение 14 дней, вернув сумму и проценты за дни пользования.")
                    }
                    PrimaryButton(title: "Принимаю условия") {
                        onAccept()
                        dismiss()
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Условия договора")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }.font(BrandFont.headline)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func clause(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.bodyM)
            .foregroundStyle(theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.rowVertical)
    }
}
