import SwiftUI

/// Deposits & staking (§9.1, §10.6): the total ₽ value at work with the best rate, then one row per
/// deposit or stake. Every row opens the savings hub (``HomeRoute.deposits``).
struct SavingsBlock: View {
    let dashboard: HomeDashboard
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        GroupedSection("Вклады и стейкинг") {
            Button(action: onTap) { summary }
                .buttonStyle(.row)
            ForEach(dashboard.deposits) { deposit in
                Button(action: onTap) { row(deposit) }
                    .buttonStyle(.row)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("В работе").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                AmountText(amount: dashboard.depositsValueRub, size: 22)
            }
            Spacer(minLength: Spacing.sm)
            if let apy = dashboard.bestDepositApy {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("до \(MoneyFormat.percent(apy, maxFractionDigits: 1))")
                        .font(BrandFont.body(17, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("годовых").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }
            }
            chevron
        }
        .padding(.vertical, Spacing.rowVertical)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func row(_ deposit: Deposit) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            glyph(deposit)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(deposit))
                    .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(subtitle(deposit))
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            AmountText(amount: deposit.principal,
                       currency: deposit.kind == .ruble ? "₽" : (deposit.asset ?? "₽"), size: 17)
                .layoutPriority(1)
            chevron
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .contentShape(Rectangle())
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func glyph(_ deposit: Deposit) -> some View {
        if deposit.kind == .stake, let asset = deposit.asset {
            CoinLogo(symbol: asset, size: ListRow.glyphSize)
        } else {
            GlyphCircle(currency: "RUB", size: ListRow.glyphSize)
        }
    }

    private func title(_ deposit: Deposit) -> String {
        switch deposit.kind {
        case .ruble: return "Вклад"
        case .stake: return "Стейкинг \(deposit.asset ?? "")"
        }
    }

    /// `16,5 % годовых · 12 мес.`: the rate, plus the term when there is one.
    private func subtitle(_ deposit: Deposit) -> String {
        let rate = "\(MoneyFormat.percent(deposit.rateApy, maxFractionDigits: 1)) годовых"
        guard let term = deposit.term else { return rate }
        return "\(rate) · \(term) мес."
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.textTertiary)
    }
}
