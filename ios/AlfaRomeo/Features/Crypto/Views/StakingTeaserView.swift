import SwiftUI

/// Стейкинг — вход из детейла актива (§9.6). Полная реализация — обновление 2.2 (§10.6 «вклад нового
/// поколения»). This is the teaser: indicative APY, how it works, an honest risk comparison vs ruble
/// deposits, and a «notify me» action. No execution here.
struct StakingTeaserView: View {
    let symbol: String

    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var prices = LivePriceService.shared
    @State private var notified = false

    private var apy: Double { MockCryptoData.stakingApy(for: symbol) ?? 4.0 }
    private var balance: Double { store.bankBalance(asset: symbol) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                howItWorks
                comparisonCard
                Text("Полноценный стейкинг с выбором валидатора и сроком блокировки появится в обновлении 2.2.")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: notified ? "Уведомим вас" : "Сообщить о запуске") {
                    withAnimation { notified = true }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Стейкинг \(symbol)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                AssetGlyph(symbol: symbol, size: ListRow.glyphSize)
                Text("Доходность \(symbol)").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Spacer()
            }
            Text("до \(MoneyFormat.percent(apy, maxFractionDigits: 1))")
                .font(BrandFont.heroAmount).foregroundStyle(theme.textPrimary)
                .monospacedDigit()
            Text("годовых, начисление ежедневно").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            if balance > 0 {
                Text("Доступно для стейкинга: \(CryptoFormat.qty(balance, symbol: symbol))")
                    .font(BrandFont.subheadline).foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var howItWorks: some View {
        GroupedSection("Как это работает") {
            step("1", "Блокируете монеты", "Активы остаются вашими, но участвуют в обеспечении сети.")
            step("2", "Получаете вознаграждение", "APY начисляется ежедневно в той же монете.")
            step("3", "Выводите, когда нужно", "По окончании срока блокировки, без штрафов.")
        }
    }

    private func step(_ n: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: ListRow.glyphSpacing) {
            GlyphCircle(text: n, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(detail).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.rowVertical)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }

    private var comparisonCard: some View {
        GroupedSection("Риски") {
            Text("Стейкинг не вклад: доход выше, но без страхования АСВ и с волатильностью цены монеты. Рублёвый вклад надёжнее, крипто-стейкинг потенциально доходнее.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.rowVertical)
        }
    }
}

#Preview {
    NavigationStack {
        StakingTeaserView(symbol: "ETH")
            .environment(\.theme, .default)
    }
}
