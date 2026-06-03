import SwiftUI

/// Honest side-by-side risk contrast for the hub (§10.6): вклад застрахован АСВ vs стейкинг —
/// рыночный риск, не застрахован. Makes the trade-off explicit *before* the user picks a product.
struct RiskComparisonStrip: View {
    @Environment(\.theme) private var theme

    var body: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                half(risk: .insuredASV, tint: theme.success)
                Rectangle().fill(theme.border).frame(width: 1)
                half(risk: .marketRisk, tint: theme.warning)
            }
        }
    }

    private func half(risk: SavingsRisk, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: risk.systemImage).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                Text(risk == .insuredASV ? "Вклад" : "Стейкинг")
                    .font(BrandFont.callout).foregroundStyle(theme.textPrimary)
            }
            Text(risk.headline).font(BrandFont.micro).foregroundStyle(tint)
            Text(risk == .insuredASV ? "Фиксированная ставка, гарантия государства."
                                     : "Доходность выше, но возможна потеря части стоимости.")
                .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Mandatory risk-acknowledgement block for the staking flow (§10.6: «обязательный чекбокс перед
/// стейком»). The confirm button stays disabled until `accepted` is true.
struct StakeRiskDisclosure: View {
    @Binding var accepted: Bool

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: SavingsRisk.marketRisk.systemImage)
                            .foregroundStyle(theme.warning)
                        Text("Это не вклад").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    }
                    Text(SavingsRisk.marketRisk.detail)
                        .font(BrandFont.body())
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    bullet("Средства НЕ застрахованы АСВ", "xmark.shield")
                    bullet("Цена актива колеблется — тело может уменьшиться", "chart.line.downtrend.xyaxis")
                    bullet("Только BTC/ETH и стейблкоины (§2.4)", "checkmark.seal")
                }
            }

            Button { accepted.toggle() } label: {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: accepted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundStyle(accepted ? theme.accent : theme.textSecondary)
                    Text("Я понимаю рыночный риск и что стейкинг не застрахован государством.")
                        .font(BrandFont.callout)
                        .foregroundStyle(theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(Spacing.md)
                .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(accepted ? theme.accent : theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(PressableButtonStyle())
            .animation(Motion.snappy, value: accepted)
        }
    }

    private func bullet(_ text: String, _ icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.warning)
                .frame(width: 18)
            Text(text).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var ok = false
        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    RiskComparisonStrip()
                    StakeRiskDisclosure(accepted: $ok)
                }.padding()
            }
            .background(Theme.default.background)
        }
    }
    return Demo().environment(\.theme, .default)
}
