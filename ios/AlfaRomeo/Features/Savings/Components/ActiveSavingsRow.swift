import SwiftUI

/// One active вклад / стейк in the hub list (§10.6 «Список активных вкладов/стейков»). Stakes show
/// their coin, unit amount and a live ₽ valuation; ruble deposits show rate and term.
struct ActiveSavingsRow: View {
    let deposit: Deposit
    let valueRub: Double      // computed by the hub (live price for stakes)
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm + 4) {
                if isStake {
                    CoinLogo(symbol: deposit.asset ?? "", size: 36)
                } else {
                    GlyphCircle(currency: "RUB")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                    Text(subtitle)
                        .font(BrandFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Text(SavingsFormat.rub(valueRub))
                    .font(BrandFont.bodyM)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: valueRub)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
        }
        .buttonStyle(.row)
        .groupedRowTextInset(48)
    }

    private var isStake: Bool { deposit.kind == .stake }

    private var title: String {
        isStake ? "Стейкинг \(deposit.asset ?? "")" : "Рублёвый вклад"
    }

    /// Two facts at most: amount + rate for a stake, rate + term for a deposit.
    private var subtitle: String {
        let rate = SavingsFormat.percent(deposit.rateApy)
        if isStake {
            return "\(SavingsFormat.units(deposit.principal, asset: deposit.asset ?? "")) · APY \(rate)"
        }
        if let term = deposit.term { return "\(rate) годовых · \(term)\(MoneyFormat.nbsp)мес" }
        return "\(rate) годовых"
    }
}

#Preview {
    GroupedSection("Мои вклады и стейки") {
        ActiveSavingsRow(deposit: Deposit(id: "d1", profileId: "p", kind: .ruble, asset: nil,
                                          principal: 500_000, rateApy: 16.5, term: 6,
                                          lockUntil: nil), valueRub: 500_000) {}
        ActiveSavingsRow(deposit: Deposit(id: "d2", profileId: "p", kind: .stake, asset: "ETH",
                                          principal: 1.0, rateApy: 4.2, term: nil,
                                          lockUntil: "2035-09-01T00:00:00Z"), valueRub: 318_000) {}
    }
    .padding()
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
