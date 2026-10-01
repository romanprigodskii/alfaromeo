import SwiftUI

/// One business account in detail (§8.2): the native balance, its live ₽ valuation (for foreign /
/// stablecoin accounts), the masked requisites, and the entry into the account's «выписка». Reads the
/// shared ``BusinessAccountsStore`` — no copies, balances stay the contract ``Account`` values.
struct AccountDetailView: View {
    let accountId: String

    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = BusinessAccountsStore.shared
    @State private var prices = LivePriceService.shared
    @State private var fx = FXRateService.shared

    private var item: BusinessAccountItem? { store.items.first { $0.id == accountId } }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    balanceHero(item)
                    detailsSection(item)
                    PrimaryButton(title: "Выписка по счёту") {
                        router.push(AccountsRoute.statements)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Счёт не найден")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.screen)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle(item?.title ?? "Счёт")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prices.start() }
        .task { await fx.start() }
    }

    private func balanceHero(_ item: BusinessAccountItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(item.subtitle)
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            AmountText(amount: item.balance,
                       currency: item.currency.uppercased() == "RUB" ? "₽" : item.currency.uppercased(),
                       size: 40, splitsKopecks: true)
            if item.showsRubEquivalent {
                HStack(spacing: Spacing.sm) {
                    Text("≈ \(MoneyFormat.fiat(item.rubValue.rounded()))")
                        .font(BrandFont.body(15, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                    livePill(item.currency)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailsSection(_ item: BusinessAccountItem) -> some View {
        GroupedSection("Реквизиты") {
            row("Номер счёта", item.maskedNumber)
            row("Валюта", item.currency.uppercased())
            if item.showsRubEquivalent {
                if AccountValuation.isForeignFiat(item.currency) {
                    row("Курс ЦБ на \(fx.dateText)",
                        [fx.rateText(item.currency), fx.changeText(item.currency)].compactMap { $0 }.joined(separator: " · "))
                } else {
                    row("Курс", "1 \(item.currency.uppercased()) ≈ \(MoneyFormat.fiat(store.rubRate(currency: item.currency)))")
                }
                row("Оценка в ₽", MoneyFormat.fiat(item.rubValue.rounded()))
            }
        }
    }

    private func row(_ label: String, _ value: String, code: Bool = false) -> some View {
        HStack {
            Text(label).font(BrandFont.bodyM).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value)
                .font(code ? BrandFont.code(17) : BrandFont.bodyM)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeight)
    }

    /// Fiat → «курс ЦБ на dd.MM» (green once fetched live this session); stablecoins → the market pill.
    private func livePill(_ currency: String) -> some View {
        let fiat = AccountValuation.isForeignFiat(currency)
        let live = fiat ? fx.isLive : prices.isLive
        return HStack(spacing: Spacing.xs) {
            Circle().fill(live ? theme.success : theme.warning).frame(width: 6, height: 6)
            Text(fiat ? fx.label : (live ? "live-курс" : "оффлайн"))
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
    }
}
