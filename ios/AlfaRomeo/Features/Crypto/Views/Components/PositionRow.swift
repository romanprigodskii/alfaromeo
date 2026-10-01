import SwiftUI

/// One position in the unified portfolio (§9.6): coin logo, name + quantity, and the live ₽ value
/// with a 24h delta. External (watch-only) positions carry a neutral read-only tag. A grouped-list
/// row (docs/DESIGN.md §5). The value
/// updates as ``LivePriceService`` ticks (the parent rebuilds positions from live prices).
struct PositionRow: View {
    let position: CryptoPosition
    /// Display currency for the ₽ value (§9.6 ₽/$ toggle). Quantity stays in asset units; only the
    /// fiat valuation re-expresses in $.
    var denomination: PortfolioDenomination = .rub
    var usdRub: Double = 1
    var onTap: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var change: Double? { position.change24hPct }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ListRow.glyphSpacing) {
                AssetGlyph(symbol: position.symbol, size: ListRow.glyphSize)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(position.title)
                            .font(BrandFont.bodyM)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if position.watchOnly { WatchOnlyTag() }
                    }
                    Text(CryptoFormat.qty(position.qty, symbol: position.symbol))
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CryptoFormat.money(position.valueRub, denom: denomination, usdRub: usdRub, fraction: 0))
                        .font(BrandFont.bodyM)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .animation(reduceMotion ? nil : Motion.snappy, value: position.valueRub)
                        .animation(reduceMotion ? nil : Motion.snappy, value: denomination)
                    if let change {
                        Text(CryptoFormat.pct(change))
                            .font(BrandFont.subheadline)
                            .foregroundStyle(change >= 0 ? theme.success : theme.danger)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}

/// Neutral «только просмотр» tag for watch-only (external) holdings: caption 12 medium on `fill`.
struct WatchOnlyTag: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("просмотр")
            .font(BrandFont.micro)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .accessibilityLabel("Только просмотр")
    }
}

#Preview {
    VStack(spacing: 0) {
        PositionRow(position: CryptoPosition(id: "1", symbol: "BTC", title: "Bitcoin",
            subtitle: "Кошелёк · Bitcoin", qty: 0.1423, unitPriceRub: 9_540_000, valueRub: 1_357_542,
            change24hPct: 2.4, kind: .bankCrypto, watchOnly: false, routeId: "BTC"))
        Divider().overlay(Theme.default.border)
        PositionRow(position: CryptoPosition(id: "2", symbol: "ETH", title: "Ethereum",
            subtitle: "Ledger · 0x7a3F…cDeF", qty: 0.41, unitPriceRub: 318_000, valueRub: 130_380,
            change24hPct: -1.1, kind: .externalCrypto, watchOnly: true, routeId: "ETH"))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
