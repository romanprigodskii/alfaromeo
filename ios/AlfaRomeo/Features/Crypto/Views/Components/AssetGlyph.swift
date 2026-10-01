import SwiftUI

/// A round asset mark for the hub, rows, and detail headers. Real coins render their **brand logo** on
/// the coin's brand colour via ``CoinLogo`` (Bitcoin ₿, Ethereum diamond, Solana bars, TON crystal,
/// ₮/$ stablecoins). A `systemImage` (e.g. a ЦФА category glyph) or an unknown ticker (AURUM…) is a
/// neutral ``GlyphCircle``: colour comes only from real coin logos (docs/DESIGN.md §2).
struct AssetGlyph: View {
    let symbol: String
    var systemImage: String? = nil
    var size: CGFloat = 40

    @Environment(\.theme) private var theme

    private var ticker: String {
        let s = symbol.uppercased()
        return s.count <= 4 ? s : String(s.prefix(3))
    }

    var body: some View {
        // A known coin → its real brand logo. `systemImage` (ЦФА categories) and unknown tickers get a
        // neutral fill circle with an ink glyph.
        if systemImage == nil, CoinVisual.isKnown(symbol) {
            CoinLogo(symbol: symbol, size: size)
        } else if let systemImage {
            GlyphCircle(systemImage: systemImage, size: size)
                .accessibilityHidden(true)
        } else {
            Text(ticker)
                .font(.system(size: size * 0.3, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 2)
                .frame(width: size, height: size)
                .background(theme.fill, in: Circle())
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        AssetGlyph(symbol: "BTC")
        AssetGlyph(symbol: "ETH")
        AssetGlyph(symbol: "AURUM")
        AssetGlyph(symbol: "CFA", systemImage: "building.columns.fill")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
