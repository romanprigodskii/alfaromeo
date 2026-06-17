import SwiftUI

/// Brand-accurate coin marks for the digital-asset hub (§9.6 / §13.1). Replaces the plain ticker text
/// on ``AssetGlyph`` with each coin's recognizable logo on its real brand colour — the way an exchange
/// surfaces tokens: Bitcoin ₿, the Ethereum octahedron, Solana's gradient bars, the TON crystal, and
/// the ₮ / $ stablecoin glyphs. Marks are vector (``Shape``/SF Symbol), so they stay crisp at any size.
///
/// Anything without a known mark (ЦФА tickers like AURUM, or a `systemImage` category glyph) keeps the
/// cold-gradient + ticker rendering in ``AssetGlyph`` — these brand marks are crypto-only.
enum CoinVisual {
    /// UPPERCASE symbols that have a dedicated brand mark below.
    private static let known: Set<String> = ["BTC", "ETH", "USDT", "USDC", "SOL", "TON"]
    static func isKnown(_ symbol: String) -> Bool { known.contains(symbol.uppercased()) }

    /// Real brand background colour per coin (SOL sits on near-black so its gradient bars pop).
    static func background(_ symbol: String) -> Color {
        switch symbol.uppercased() {
        case "BTC":  return Color(hex: 0xF7931A)   // Bitcoin orange
        case "ETH":  return Color(hex: 0x627EEA)   // Ethereum periwinkle
        case "USDT": return Color(hex: 0x26A17B)   // Tether green
        case "USDC": return Color(hex: 0x2775CA)   // Circle blue
        case "SOL":  return Color(hex: 0x131722)   // dark, for the gradient bars
        case "TON":  return Color(hex: 0x0098EA)   // TON blue
        default:     return Color(hex: 0x4F7CFF)
        }
    }
}

/// One coin's logo on its brand-coloured disc. Used by ``AssetGlyph`` for known coins.
struct CoinLogo: View {
    let symbol: String
    var size: CGFloat = 40

    private var key: String { symbol.uppercased() }

    var body: some View {
        ZStack {
            Circle().fill(CoinVisual.background(key))
            mark
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var mark: some View {
        switch key {
        case "BTC":
            Image(systemName: "bitcoinsign")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)
        case "USDC":
            Image(systemName: "dollarsign")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
        case "USDT":
            // ₮ (U+20AE) — the Tether mark; rounded-bold reads as the coin glyph.
            Text("\u{20AE}")
                .font(.system(size: size * 0.56, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        case "ETH":
            EthereumMark()
                .fill(.white)
                .frame(width: size * 0.38, height: size * 0.60)
        case "SOL":
            SolanaMark()
                .fill(LinearGradient(colors: [Color(hex: 0x9945FF), Color(hex: 0x14F195)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.58, height: size * 0.54)
        case "TON":
            ZStack {
                TonMark().fill(.white)
                TonFacets().stroke(CoinVisual.background("TON"), lineWidth: max(1, size * 0.03))
            }
            .frame(width: size * 0.60, height: size * 0.56)
        default:
            Text(key.prefix(3))
                .font(BrandFont.mono(size * 0.3, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Vector marks

/// The Ethereum octahedron — two kites (upper + lower) with the iconic white gap, canonical proportions
/// (256×417 viewBox normalized to the rect).
private struct EthereumMark: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        // Upper kite
        path.move(to: p(0.5, 0.0))
        path.addLine(to: p(0.975, 0.509))
        path.addLine(to: p(0.5, 0.691))
        path.addLine(to: p(0.025, 0.509))
        path.closeSubpath()
        // Lower kite
        path.move(to: p(0.5, 0.749))
        path.addLine(to: p(0.975, 0.568))
        path.addLine(to: p(0.5, 1.0))
        path.addLine(to: p(0.025, 0.568))
        path.closeSubpath()
        return path
    }
}

/// Solana's three slanted bars (parallelograms), top/bottom aligned, the middle offset right — the
/// brand gradient flows across all three.
private struct SolanaMark: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        let sk: CGFloat = 0.22   // top-edge skew → "/" slant
        let bh: CGFloat = 0.21   // bar height
        var path = Path()
        func bar(_ xl: CGFloat, _ xr: CGFloat, _ y: CGFloat) {
            path.move(to: p(xl + sk, y))
            path.addLine(to: p(xr + sk, y))
            path.addLine(to: p(xr, y + bh))
            path.addLine(to: p(xl, y + bh))
            path.closeSubpath()
        }
        bar(0.0,  0.70, 0.06)   // top
        bar(0.08, 0.78, 0.395)  // middle (offset right)
        bar(0.0,  0.70, 0.73)   // bottom
        return path
    }
}

/// The TON crystal — a flat-top gem tapering to a point.
private struct TonMark: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.07, 0.27))
        path.addLine(to: p(0.93, 0.27))
        path.addLine(to: p(0.5, 0.95))
        path.closeSubpath()
        return path
    }
}

/// Facet seams carved over ``TonMark`` (in the brand colour): the top inverted-V + the front ridge —
/// the horizontal top edge + the ridge read as the subtle TON "T".
private struct TonFacets: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.07, 0.27))
        path.addLine(to: p(0.5, 0.47))
        path.addLine(to: p(0.93, 0.27))
        path.move(to: p(0.5, 0.47))
        path.addLine(to: p(0.5, 0.95))
        return path
    }
}

#Preview {
    let coins = ["BTC", "ETH", "USDT", "USDC", "SOL", "TON"]
    return VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
            ForEach(coins, id: \.self) { CoinLogo(symbol: $0, size: 48) }
        }
        HStack(spacing: Spacing.md) {
            ForEach(coins, id: \.self) { CoinLogo(symbol: $0, size: 28) }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
