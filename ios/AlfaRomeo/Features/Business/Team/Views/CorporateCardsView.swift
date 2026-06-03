import SwiftUI

/// Corporate cards on employees (§8.2 «виртуальные/пластик на сотрудников, лимиты»). Lists every
/// card with its holder + monthly-limit gauge; «Выпустить» starts the issue flow.
struct CorporateCardsView: View {
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @State private var store = TeamStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summaryCard
                SurfaceCard(padding: Spacing.sm) {
                    if store.corpCards.isEmpty {
                        Text("Ещё нет корп-карт.").font(BrandFont.caption)
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Spacing.sm)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.corpCards.enumerated()), id: \.element.id) { index, card in
                                if index > 0 { Divider().overlay(theme.border) }
                                Button { router.push(TeamRoute.corpCardDetail(cardId: card.id)) } label: {
                                    CorpCardRow(card: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                PrimaryButton(title: "Выпустить корп-карту", icon: "creditcard.and.123") {
                    router.push(TeamRoute.issueCard(memberId: nil))
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Корп-карты")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        let totalLimit = store.corpCards.reduce(0) { $0 + $1.monthlyLimit }
        let totalSpent = store.corpCards.reduce(0) { $0 + $1.monthlySpent }
        return SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Расходы команды в этом месяце")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                AmountText(amount: totalSpent, currency: "₽", size: 28)
                ProgressBar(value: totalLimit > 0 ? totalSpent / totalLimit : 0, height: 8)
                Text("Лимит \(SupplierPaymentModel.rub(totalLimit)) на \(store.corpCards.count) карт")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary).monospacedDigit()
            }
        }
    }
}
