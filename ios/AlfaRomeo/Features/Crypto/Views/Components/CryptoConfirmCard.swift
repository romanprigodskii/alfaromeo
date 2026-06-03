import SwiftUI

/// One detail row in a crypto preview (курс / спред / комиссия сети / итог).
struct CryptoConfirmRow: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: String
    var emphasized: Bool = false
    var accent: Bool = false
}

/// The «Подтверждение» summary for crypto operations (§10.8): крупная пара «отдаёте → получаете», курс
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
        VStack(spacing: Spacing.md) {
            Text(title).font(BrandFont.headline).foregroundStyle(theme.textSecondary)

            HStack(alignment: .center, spacing: Spacing.md) {
                leg(title: "Отдаёте", value: payValue, symbol: paySymbol)
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                leg(title: "Получаете", value: getValue, symbol: getSymbol)
            }

            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().overlay(theme.border) }
                        HStack {
                            Text(row.label)
                                .font(BrandFont.callout)
                                .foregroundStyle(theme.textSecondary)
                            Spacer(minLength: Spacing.sm)
                            Text(row.value)
                                .font(row.emphasized ? BrandFont.headline : BrandFont.callout.weight(.medium))
                                .foregroundStyle(row.accent ? (theme.accentCrypto.first ?? theme.accent) : theme.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }
            }
        }
    }

    private func leg(title: String, value: String, symbol: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            Text(value)
                .font(BrandFont.mono(20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(symbol).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
