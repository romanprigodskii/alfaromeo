import SwiftUI

/// The unified ₽-equivalent header for the digital-asset hub (§9.6: «единый ₽-эквивалент портфеля
/// сверху»). One cold-gradient hero over крипта + ЦФА + внешние кошельки, with the live 24h delta and
/// a LIVE indicator that pulses while ``LivePriceService`` streams. The total ticks as prices update.
struct PortfolioHeroCard: View {
    let summary: PortfolioSummary
    let isLive: Bool
    /// Display currency for the total + breakdowns (§9.6 ₽/$ toggle). The card hosts the toggle.
    @Binding var denomination: PortfolioDenomination
    /// Live USD/₽ rate used when `denomination == .usd` (``LivePriceService/usdRub``).
    var usdRub: Double = 1

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var up: Bool { summary.change24hRub >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text("Цифровые активы")
                    .font(BrandFont.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                liveTag
            }

            Text(CryptoFormat.money(summary.totalRub, denom: denomination, usdRub: usdRub, fraction: 0))
                .font(BrandFont.mono(34, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText())
                .animation(reduceMotion ? nil : Motion.snappy, value: summary.totalRub)
                .animation(reduceMotion ? nil : Motion.snappy, value: denomination)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    // The % is denomination-independent; only the absolute amount re-expresses in $.
                    Text("\(CryptoFormat.money(abs(summary.change24hRub), denom: denomination, usdRub: usdRub, fraction: 0)) · \(CryptoFormat.pct(summary.change24hPct))")
                        .font(BrandFont.callout.weight(.semibold))
                        .monospacedDigit()
                    Text("за 24ч").font(BrandFont.caption).opacity(0.8)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(.white.opacity(0.18), in: Capsule())

                Spacer(minLength: Spacing.xs)

                denomToggle
            }

            Divider().overlay(.white.opacity(0.25))

            HStack(spacing: Spacing.md) {
                breakdown("Крипта", summary.cryptoRub - summary.externalRub)
                breakdown("ЦФА", summary.cfaRub)
                breakdown("Внешние", summary.externalRub)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cryptoGradient)
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .onAppear { pulse = true }
    }

    /// Bybit-style ₽/$ denomination switch — a small two-segment pill on the gradient. White-filled
    /// selected segment, translucent-white idle. Toggles total + breakdowns + positions (via the hub).
    private var denomToggle: some View {
        HStack(spacing: 0) {
            ForEach(PortfolioDenomination.allCases) { d in
                let selected = denomination == d
                Button {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { denomination = d }
                } label: {
                    Text(d.symbol)
                        .font(BrandFont.caption.weight(.bold))
                        .monospacedDigit()
                        .frame(width: 30, height: 26)
                        .foregroundStyle(selected ? Color.black.opacity(0.85) : .white.opacity(0.7))
                        .background {
                            if selected { Capsule().fill(.white.opacity(0.95)) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.white.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Валюта отображения")
        .accessibilityValue(denomination == .rub ? "Рубли" : "Доллары")
        .accessibilityAddTraits(.isButton)
    }

    private var liveTag: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .opacity(isLive && pulse && !reduceMotion ? 0.35 : 1)
                .animation(isLive && !reduceMotion ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: pulse)
            Text(isLive ? "LIVE" : "КЭШ")
                .font(BrandFont.micro.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 3)
        .background(.white.opacity(0.18), in: Capsule())
        .accessibilityLabel(isLive ? "Живые цены" : "Кэшированные цены")
    }

    private func breakdown(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BrandFont.micro).foregroundStyle(.white.opacity(0.75))
            Text(CryptoFormat.compactMoney(value, denom: denomination, usdRub: usdRub))
                .font(BrandFont.callout.weight(.semibold))
                .foregroundStyle(.white)
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
        isLive: true,
        denomination: .constant(.rub),
        usdRub: 92
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
