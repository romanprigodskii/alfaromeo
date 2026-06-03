import SwiftUI

/// One position in the unified portfolio (§9.6): asset mark, name + source, quantity, and the live ₽
/// value with a 24h delta. External (watch-only) positions carry a clear read-only badge. The value
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
            HStack(spacing: Spacing.md) {
                AssetGlyph(symbol: position.symbol, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(position.title)
                            .font(BrandFont.bodyM.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if position.watchOnly {
                            Text("watch-only")
                                .font(BrandFont.micro.weight(.medium))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(theme.elevated, in: Capsule())
                                .overlay(Capsule().stroke(theme.border, lineWidth: 1))
                        }
                    }
                    Text(position.subtitle)
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(CryptoFormat.money(position.valueRub, denom: denomination, usdRub: usdRub, fraction: 0))
                        .font(BrandFont.amountS)
                        .foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .animation(reduceMotion ? nil : Motion.snappy, value: position.valueRub)
                        .animation(reduceMotion ? nil : Motion.snappy, value: denomination)
                    HStack(spacing: Spacing.xs) {
                        Text(CryptoFormat.qty(position.qty, symbol: position.symbol))
                            .font(BrandFont.micro)
                            .foregroundStyle(theme.textSecondary)
                        if let change {
                            Text(CryptoFormat.pct(change))
                                .font(BrandFont.micro.weight(.semibold))
                                .foregroundStyle(change >= 0 ? theme.success : theme.danger)
                        }
                    }
                }
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
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
