import SwiftUI

/// One detail row in a crypto preview (курс / спред / комиссия сети / итог).
struct CryptoConfirmRow: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: String
    var emphasized: Bool = false
    var accent: Bool = false
}

/// The «Подтверждение» summary for crypto operations (§10.8), one grouped list: the «отдаёте → получаете»
/// pair as the first row, then курс
/// по live-цене, спред (зависит от тира), комиссия и итог — pure presentation, values precomputed by
/// the flow model. Used by convert / trade; send reuses the Payments ``ConfirmSummaryCard``.
struct CryptoConfirmCard: View {
    let title: String
    let payValue: String
    let paySymbol: String
    let getValue: String
    let getSymbol: String
    let rows: [CryptoConfirmRow]

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.md)
            GroupedSection {
                HStack(alignment: .center, spacing: Spacing.sm) {
                    leg(title: "Отдаёте", value: payValue, symbol: paySymbol)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(theme.textTertiary)
                    leg(title: "Получаете", value: getValue, symbol: getSymbol)
                }
                .padding(.vertical, Spacing.md)

                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .font(BrandFont.bodyM)
                            .foregroundStyle(theme.textSecondary)
                        Spacer(minLength: Spacing.sm)
                        Text(row.value)
                            .font(row.emphasized ? BrandFont.headline : BrandFont.bodyM)
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, Spacing.rowVertical)
                }
            }
        }
    }

    private func leg(title: String, value: String, symbol: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(title).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            Text(value)
                .font(BrandFont.amountFace(22))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(symbol).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CryptoConfirmCard(
        title: "Обмен по live-курсу",
        payValue: "0,1", paySymbol: "BTC",
        getValue: "947 412", getSymbol: "₽",
        rows: [
            CryptoConfirmRow(label: "Курс", value: "9 474 120 ₽"),
            CryptoConfirmRow(label: "Спред (Pro)", value: "0,75 %", accent: true),
            CryptoConfirmRow(label: "Комиссия", value: "Без комиссии"),
            CryptoConfirmRow(label: "Итог", value: "947 412 ₽", emphasized: true),
        ]
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
