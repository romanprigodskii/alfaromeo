import SwiftUI

/// The cash-gap warning (§8.2) — the single most valuable insight: the projected liquidity shortfall
/// with its AMOUNT and DATE («Через 14 дней — дефицит ~1,2 млн ₽ · 17 июня»). Tapping «Спросить AI»
/// drops the question into the chat so Claude explains how to close the gap.
struct CashGapAlertCard: View {
    let gap: CashGap
    var onAsk: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.danger)
                Text("Риск кассового разрыва")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                StatusPill(status: .warning, text: BizFormat.inDays(gap.inDays))
            }

            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                AmountText(amount: -gap.amount, currency: "₽", size: 26, colorBySign: true)
                Text("· \(BizFormat.dayMonth(gap.date))")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }

            Text("Прогнозируемый дефицит ликвидности. Закрыть его помогут: ускорить оплату дебиторки, перенести крупный платёж поставщику или подключить овердрафт.")
                .font(BrandFont.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onAsk) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles").font(.system(size: 12, weight: .bold))
                    Text("Спросить AI, как закрыть разрыв").font(BrandFont.caption.weight(.semibold))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.xxs)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.danger.opacity(0.35), lineWidth: 1)
        )
    }
}
