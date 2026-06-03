import SwiftUI

/// A round asset mark on the cold crypto/ЦФА gradient (§13.1) with the ticker — the visual identity
/// used across the hub, rows, and detail headers. Optionally renders an SF Symbol instead of the
/// ticker (e.g. a ЦФА category glyph).
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
        ZStack {
            Circle().fill(theme.cryptoGradient)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(ticker)
                    .font(BrandFont.mono(size * 0.3, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
