import SwiftUI

/// The unified ₽-equivalent header for the digital-asset hub (§9.6: «единый ₽-эквивалент портфеля
/// сверху»): one total over крипта + ЦФА + внешние кошельки, the live 24h delta and an honest
/// price-source badge (``PriceSourceBadge``: «LIVE · Binance» pulsing while a real feed streams,
/// «Демо-цены» offline). Flat on the screen background (docs/DESIGN.md §2/§4): no card, no gradient.
/// The total ticks as prices update.
struct PortfolioHeroCard: View {
    let summary: PortfolioSummary
    /// Active leg of ``LivePriceService``, drives the source badge.
    let source: PriceSource
    var isStale: Bool = false
    /// Display currency for the total + breakdowns (§9.6 ₽/$ toggle). The header hosts the toggle.
    @Binding var denomination: PortfolioDenomination
    /// Live USD/₽ rate used when `denomination == .usd` (``LivePriceService/usdRub``).
    var usdRub: Double = 1

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var up: Bool { summary.change24hRub >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text("Цифровые активы")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: Spacing.sm)
                    PriceSourceBadge(source: source, isStale: isStale)
                }

                Text(CryptoFormat.money(summary.totalRub, denom: denomination, usdRub: usdRub, fraction: 0))
                    .font(BrandFont.heroAmount)
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .animation(reduceMotion ? nil : Motion.snappy, value: summary.totalRub)
                    .animation(reduceMotion ? nil : Motion.snappy, value: denomination)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: Spacing.sm) {
                    // The % is denomination-independent; only the absolute amount re-expresses in $.
                    Text("\(signedMoney) (\(CryptoFormat.pct(summary.change24hPct))) за 24 ч")
                        .font(BrandFont.subheadline)
                        .foregroundStyle(up ? theme.success : theme.danger)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)   // real 24h figures vary in width, never wrap the %
                    Spacer(minLength: Spacing.sm)
                    denomToggle
                }
            }

            HStack(spacing: Spacing.md) {
                breakdown("Крипта", summary.cryptoRub - summary.externalRub)
                breakdown("ЦФА", summary.cfaRub)
                breakdown("Внешние", summary.externalRub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var signedMoney: String {
        let amount = CryptoFormat.money(abs(summary.change24hRub), denom: denomination, usdRub: usdRub, fraction: 0)
        return (up ? "+" : MoneyFormat.minus) + amount
    }

    /// ₽/$ denomination switch: a small flat two-segment control (fill track, surface thumb).
    private var denomToggle: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioDenomination.allCases) { d in
                let selected = denomination == d
                Button {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { denomination = d }
                } label: {
                    Text(d.symbol)
                        .font(BrandFont.footnote.weight(.semibold))
                        .frame(width: 32, height: 26)
                        .foregroundStyle(selected ? theme.textPrimary : theme.textSecondary)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surface)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Валюта отображения")
        .accessibilityValue(denomination == .rub ? "Рубли" : "Доллары")
        .accessibilityAddTraits(.isButton)
    }

    private func breakdown(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            Text(CryptoFormat.compactMoney(value, denom: denomination, usdRub: usdRub))
                .font(BrandFont.callout)
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PortfolioHeroCard(
        summary: PortfolioSummary(totalRub: 2_184_300, cryptoRub: 1_820_000, cfaRub: 120_300,
                                  externalRub: 244_000, change24hRub: 31_200, change24hPct: 1.45),
        source: .exchange(.binance),
        denomination: .constant(.rub),
        usdRub: 92
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
