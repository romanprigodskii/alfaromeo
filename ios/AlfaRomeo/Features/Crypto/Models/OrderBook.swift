import Foundation

/// The order book (стакан) for the trading detail (§9.6). The backend tracks price ticks, not depth
/// (§11.4), so the ladder is **deterministically generated around the live mid** — the licence the
/// user granted («мок-глубину можно сгенерировать вокруг реальной цены»). Sizes are stable per level
/// (seeded by symbol+index); only the centre slides as the live price moves, so the book looks alive
/// without reshuffling every tick. Pure value type — the view renders it.

/// One price level. `side` drives color (ask = sell = red, bid = buy = green); `depthFraction` is the
/// cumulative size normalized to the deepest level, for the background depth bar.
struct OrderBookLevel: Identifiable, Hashable {
    enum Side { case ask, bid }
    let side: Side
    let price: Double
    let size: Double
    let cumulative: Double
    let depthFraction: Double   // 0…1 vs. the deepest level on either side
    var id: String { "\(side)-\(price)" }
}

struct OrderBook: Hashable {
    /// Highest ask first (top of the book) down to the best ask (just above mid).
    let asks: [OrderBookLevel]
    /// Best bid first (just below mid) down to the lowest bid.
    let bids: [OrderBookLevel]
    let mid: Double
    /// Share of total size resting on the bid side, 0…1 — drives the B%/S% ratio bar.
    let bidShare: Double

    var bidPercent: Int { Int((bidShare * 100).rounded()) }
    var askPercent: Int { 100 - bidPercent }

    /// Build a `levels`-deep ladder around `mid`. `tickPct` is the price step as a fraction of mid;
    /// the centre is snapped to the tick so small live ticks don't reshuffle the rows.
    static func make(symbol: String, mid: Double, levels: Int = 8, tickPct: Double = 0.0006) -> OrderBook {
        guard mid > 0 else { return OrderBook(asks: [], bids: [], mid: mid, bidShare: 0.5) }
        let seed = DeterministicNoise.seed(symbol)
        let tick = max(mid * tickPct, 0.0001)
        let center = (mid / tick).rounded() * tick

        // Sizes are stable per level index; deeper levels trend slightly larger (typical book shape).
        func size(_ tag: UInt64, _ i: Int) -> Double {
            let base = 0.35 + DeterministicNoise.unit(seed &+ tag, UInt64(i)) * 1.25
            return base * (1 + Double(i) * 0.12)
        }

        var askSizes: [Double] = []
        var bidSizes: [Double] = []
        for i in 1...levels {
            askSizes.append(size(101, i))
            bidSizes.append(size(202, i))
        }
        let askTotal = askSizes.reduce(0, +)
        let bidTotal = bidSizes.reduce(0, +)

        // Cumulative depth grows from the inside (best price, nearest mid) outward.
        var askCum: [Double] = []; var run = 0.0
        for s in askSizes { run += s; askCum.append(run) }
        var bidCum: [Double] = []; run = 0.0
        for s in bidSizes { run += s; bidCum.append(run) }
        let maxCum = max(askCum.last ?? 1, bidCum.last ?? 1)

        // Asks: best ask is i=1 (closest to mid); display highest price at the top → reverse.
        let asksInside: [OrderBookLevel] = (1...levels).map { i in
            OrderBookLevel(side: .ask, price: center + Double(i) * tick,
                           size: askSizes[i - 1], cumulative: askCum[i - 1],
                           depthFraction: maxCum > 0 ? askCum[i - 1] / maxCum : 0)
        }
        let bids: [OrderBookLevel] = (1...levels).map { i in
            OrderBookLevel(side: .bid, price: center - Double(i) * tick,
                           size: bidSizes[i - 1], cumulative: bidCum[i - 1],
                           depthFraction: maxCum > 0 ? bidCum[i - 1] / maxCum : 0)
        }

        let total = askTotal + bidTotal
        return OrderBook(asks: asksInside.reversed(), bids: bids, mid: mid,
                         bidShare: total > 0 ? bidTotal / total : 0.5)
    }
}
