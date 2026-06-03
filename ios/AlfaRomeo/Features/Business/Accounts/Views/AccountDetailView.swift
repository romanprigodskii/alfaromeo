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

    private var item: BusinessAccountItem? { store.items.first { $0.id == accountId } }

    var body: some View {
        ScrollView {
            if let item {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    balanceCard(item)
                    detailsCard(item)
                    PrimaryButton(title: "Выписка по счёту", icon: "doc.text") {
                        router.push(AccountsRoute.statements)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Счёт не найден")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .padding(Spacing.lg)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle(item?.title ?? "Счёт")
        .navigationBarTitleDisplayMode(.inline)
        .task { await prices.start() }
    }

    private func balanceCard(_ item: BusinessAccountItem) -> some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(item.subtitle.uppercased())
                    .font(BrandFont.micro.weight(.semibold)).tracking(1.1)
                    .foregroundStyle(theme.textSecondary)
                AmountText(amount: item.balance,
                           currency: item.currency.uppercased() == "RUB" ? "₽" : item.currency.uppercased(),
                           size: 34)
                if item.showsRubEquivalent {
                    HStack(spacing: Spacing.sm) {
                        Text("≈ \(CryptoFormat.rub(item.rubValue))")
                            .font(BrandFont.callout.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                            .monospacedDigit()
                        livePill
                    }
                }
            }
        }
    }

    private func detailsCard(_ item: BusinessAccountItem) -> some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                row("Номер счёта", item.maskedNumber)
                Divider().overlay(theme.border)
                row("Валюта", item.currency.uppercased())
                if item.showsRubEquivalent {
                    Divider().overlay(theme.border)
                    row("Курс", "1 \(item.currency.uppercased()) ≈ \(CryptoFormat.rub(store.rubRate(currency: item.currency), fraction: 2))")
                    Divider().overlay(theme.border)
                    row("Оценка в ₽", CryptoFormat.rub(item.rubValue))
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(value).font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var livePill: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(prices.isLive ? theme.success : theme.warning).frame(width: 6, height: 6)
            Text(prices.isLive ? "live-курс" : "оффлайн")
                .font(BrandFont.micro.weight(.medium)).foregroundStyle(theme.textSecondary)
        }
    }
}
