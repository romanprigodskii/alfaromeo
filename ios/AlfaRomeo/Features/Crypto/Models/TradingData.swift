import Foundation

/// Pro-trading chart data for the crypto asset detail (§9.6 «график, таймфреймы»). Exchange-style
/// timeframe tabs (15м / 1Ч / 4Ч / 1Д). Every frame uses **real** exchange klines loaded by
/// ``AssetDetailModel``; only when no source answers (offline, or USDT which has no USDT pair) is a
/// series deterministically synthesized around the **live** price (the same mock-around-real-price
/// licence the order book uses, §11.4) — and captioned «синтетика». Pure value helpers — no view state.

// MARK: - Timeframe

/// Bybit-style interval tabs for the trading chart. Lives in Features/Crypto (the Networking
/// ``CandleRange`` is range-based); each tab maps 1:1 onto an exchange kline interval.
enum Timeframe: String, CaseIterable, Identifiable, Hashable, Sendable {
    case m15, h1, h4, d1
    var id: String { rawValue }

    var title: String {
        switch self {
        case .m15: return "15м"
        case .h1:  return "1Ч"
        case .h4:  return "4Ч"
        case .d1:  return "1Д"
        }
    }

    var isIntraday: Bool { self != .d1 }

    /// Binance kline interval token (case-sensitive: `1h`, not `1H`).
    var klineInterval: String {
        switch self {
        case .m15: return "15m"
        case .h1:  return "1h"
        case .h4:  return "4h"
        case .d1:  return "1d"
        }
    }

    var candleCount: Int {
        switch self {
        case .m15: return 48   // 12h of 15-min candles
        case .h1:  return 48   // 2 days of hourly
        case .h4:  return 42   // ~7 days of 4h
        case .d1:  return 30
        }
    }

    var bucketSeconds: TimeInterval {
        switch self {
        case .m15: return 900
        case .h1:  return 3_600
        case .h4:  return 14_400
        case .d1:  return 86_400
        }
    }

    /// Per-candle volatility / wick amplitude for the synthetic walk — larger on longer frames.
    fileprivate var drift: Double {
        switch self {
        case .m15: return 0.006
        case .h1:  return 0.012
        case .h4:  return 0.022
        case .d1:  return 0.030
        }
    }
    fileprivate var wick: Double {
        switch self {
        case .m15: return 0.004
        case .h1:  return 0.008
        case .h4:  return 0.013
        case .d1:  return 0.016
        }
    }
    fileprivate var seedSalt: UInt64 {
        switch self {
        case .m15: return 11
        case .h1:  return 23
        case .h4:  return 37
        case .d1:  return 53
        }
    }
}

/// Candle vs. line rendering for the price panel.
enum ChartStyle: String, CaseIterable, Identifiable, Hashable {
    case candles, line
    var id: String { rawValue }
    var title: String { self == .candles ? "Свечи" : "Линия" }
    var icon: String { self == .candles ? "chart.bar.fill" : "chart.xyaxis.line" }
}

/// Optional bottom indicator panel (§9.6 «опциональный индикатор снизу (MACD/объём)»).
enum ChartIndicator: String, CaseIterable, Identifiable, Hashable {
    case none, volume, macd
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none:   return "Нет"
        case .volume: return "Объём"
        case .macd:   return "MACD"
        }
    }
}

// MARK: - Deterministic noise

/// Stable [0,1) pseudo-noise from two integer seeds — no `Date()`/`Math.random`, so charts and the
/// order book look alive but never reshuffle between renders. Shared by the synthetic candle walk and
/// the order-book depth ladder.
enum DeterministicNoise {
    /// A stable per-process-independent seed for a symbol (mirrors ``MockData`` candle seeding).
    static func seed(_ string: String) -> UInt64 {
        UInt64(string.uppercased().unicodeScalars.reduce(UInt32(2_166_136_261)) { acc, scalar in
            (acc ^ scalar.value) &* 16_777_619
        })
    }

    static func unit(_ a: UInt64, _ b: UInt64) -> Double {
        var x = a &* 0x9E37_79B9_7F4A_7C15 &+ (b &+ 1) &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 30; x = x &* 0xBF58_476D_1CE4_E5B9
        x ^= x >> 27; x = x &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x >> 11) / Double(UInt64(1) << 53)
    }
}

// MARK: - Synthetic intraday candles

enum SyntheticMarket {
    /// A deterministic OHLC walk for an intraday `timeframe`, **affine-rescaled** so the last close
    /// equals the live `mid`. The walk shape is seeded by `(symbol, timeframe, index)` only, so when
    /// the live price ticks the whole series scales smoothly (the last candle slides) instead of
    /// being regenerated — no jitter.
    static func intraday(symbol: String, timeframe: Timeframe, mid: Double, now: Date) -> [PriceCandle] {
        guard mid > 0 else { return [] }
        let count = timeframe.candleCount
        let base = DeterministicNoise.seed(symbol) &+ timeframe.seedSalt

        var price = 1.0
        var raw: [(o: Double, h: Double, l: Double, c: Double)] = []
        raw.reserveCapacity(count)
        for i in 0..<count {
            let d = (DeterministicNoise.unit(base, UInt64(i) &* 2) - 0.48) * timeframe.drift
            let open = price
            let close = max(0.0001, open * (1 + d))
            let high = max(open, close) * (1 + DeterministicNoise.unit(base, UInt64(i) &* 2 &+ 1) * timeframe.wick)
            let low  = min(open, close) * (1 - DeterministicNoise.unit(base, UInt64(i) &+ 7_919) * timeframe.wick)
            raw.append((open, high, low, close))
            price = close
        }

        let last = raw.last?.c ?? 1
        let k = last > 0 ? mid / last : 1
        let fmt = ISO8601DateFormatter()
        let step = timeframe.bucketSeconds
        return raw.enumerated().map { i, c in
            let t = fmt.string(from: now.addingTimeInterval(-Double(count - 1 - i) * step))
            return PriceCandle(t: t, o: c.o * k, h: c.h * k, l: c.l * k, c: c.c * k)
        }
    }
}

// MARK: - Indicators

/// One bar of the volume sub-panel, colored by direction (зелёный вверх / красный вниз). Real traded
/// volume when the candle came from exchange klines (``PriceCandle/v``); otherwise a plausible series
/// derived from the candle body+range (backend / synthetic candles carry no volume).
struct VolumeBar: Identifiable, Hashable {
    let index: Int
    let value: Double
    let up: Bool
    var id: Int { index }
}

/// One point of the MACD sub-panel (EMA12 − EMA26, signal EMA9, histogram).
struct MACDPoint: Identifiable, Hashable {
    let index: Int
    let macd: Double
    let signal: Double
    var histogram: Double { macd - signal }
    var id: Int { index }
}

enum TechnicalIndicators {
    static func volume(_ candles: [PriceCandle], symbol: String) -> [VolumeBar] {
        let seed = DeterministicNoise.seed(symbol)
        return candles.enumerated().map { i, c in
            let body = abs(c.c - c.o)
            let range = max(c.h - c.l, body)
            let jitter = 0.6 + DeterministicNoise.unit(seed, UInt64(i)) * 0.8
            return VolumeBar(index: i, value: c.v ?? (range + body) * jitter, up: c.c >= c.o)
        }
    }

    static func macd(_ candles: [PriceCandle], fast: Int = 12, slow: Int = 26, signalPeriod: Int = 9) -> [MACDPoint] {
        let closes = candles.map(\.c)
        guard closes.count > 1 else { return [] }
        let emaFast = ema(closes, period: fast)
        let emaSlow = ema(closes, period: slow)
        let macdLine = zip(emaFast, emaSlow).map { $0 - $1 }
        let signal = ema(macdLine, period: signalPeriod)
        return (0..<macdLine.count).map { i in
            MACDPoint(index: i, macd: macdLine[i], signal: signal[i])
        }
    }

    /// Exponential moving average, seeded with the first value (standard streaming EMA).
    static func ema(_ values: [Double], period: Int) -> [Double] {
        guard let first = values.first else { return [] }
        let k = 2.0 / (Double(period) + 1)
        var prev = first
        return values.enumerated().map { i, v in
            if i == 0 { return v }
            prev = v * k + prev * (1 - k)
            return prev
        }
    }
}
