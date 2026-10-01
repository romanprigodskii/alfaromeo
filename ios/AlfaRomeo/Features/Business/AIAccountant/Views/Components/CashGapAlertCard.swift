import SwiftUI

/// The cash-gap warning (§8.2), the single most valuable insight: the projected liquidity shortfall
/// with its AMOUNT and DATE. The «через N дней» pill carries the warning state; the card itself is flat. Tapping «Спросить AI»
/// drops the question into the chat so Claude explains how to close the gap.
struct CashGapAlertCard: View {
    let gap: CashGap
    var onAsk: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text("Риск кассового разрыва")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                StatusPill(status: .warning, text: BizFormat.inDays(gap.inDays))
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                AmountText(amount: -gap.amount, currency: "₽", size: 26, colorBySign: true)
                Text("к \(BizFormat.dayMonth(gap.date))")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }

            Text("Прогнозируемый дефицит ликвидности. Закрыть его помогут: ускорить оплату дебиторки, перенести крупный платёж поставщику или подключить овердрафт.")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAsk) {
                Text("Спросить, как закрыть разрыв")
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
