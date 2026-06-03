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
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: notified ? "Уведомим вас" : "Сообщить о запуске",
                              icon: notified ? "checkmark" : "bell.badge") {
                    withAnimation { notified = true }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Стейкинг \(symbol)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                AssetGlyph(symbol: symbol, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Стейкинг \(symbol)").font(BrandFont.headline).foregroundStyle(.white)
                    Text("Вклад нового поколения").font(BrandFont.caption).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            Text("до \(CryptoFormat.pct(apy, fraction: 1))")
                .font(BrandFont.mono(34, weight: .bold)).foregroundStyle(.white)
            Text("годовых · начисление ежедневно").font(BrandFont.caption).foregroundStyle(.white.opacity(0.85))
            if balance > 0 {
                Text("Доступно для стейкинга: \(CryptoFormat.qty(balance, symbol: symbol))")
                    .font(BrandFont.caption.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, Spacing.xs)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cryptoGradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }

    private var howItWorks: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Как это работает").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                step("1", "Блокируете монеты", "Активы остаются вашими, но участвуют в обеспечении сети.")
                step("2", "Получаете вознаграждение", "APY начисляется ежедневно в той же монете.")
                step("3", "Выводите когда нужно", "По окончании срока блокировки — без штрафов.")
            }
        }
    }

    private func step(_ n: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle().fill((theme.accentCrypto.first ?? theme.accent).opacity(0.16)).frame(width: 28, height: 28)
                Text(n).font(BrandFont.caption.weight(.bold)).foregroundStyle(theme.accentCrypto.first ?? theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(detail).font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var comparisonCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Честно о рисках").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Стейкинг — не вклад: доход выше, но без страхования АСВ и с волатильностью цены монеты. Рублёвый вклад надёжнее, крипто-стейкинг потенциально доходнее.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        StakingTeaserView(symbol: "ETH")
            .environment(\.theme, .default)
    }
}
