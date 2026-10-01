import SwiftUI
import Charts

/// The exchange-style price chart for the asset detail (§9.6 «график, таймфреймы»): Bybit-density
/// timeframe tabs (15м / 1Ч / 4Ч / 1Д), a candles/line toggle, a live period-delta chip, and an
/// optional bottom indicator panel (Объём / MACD) that shares the price panel's x-scale.
///
/// Every timeframe renders **real** exchange klines from ``AssetDetailModel`` (fetched per tab), with
/// the last candle pinned to the live price so the chart agrees with the header. Only when no source
/// answers does it fall back to ``SyntheticMarket`` around the live price — and the caption says
/// «синтетика». Reads the ambient `theme.*` tokens (light, like the rest of the app).
struct TradingChartView: View {
    let symbol: String
    var model: AssetDetailModel

    @Environment(\.theme) private var theme
    @State private var prices = LivePriceService.shared

    @State private var timeframe: Timeframe = .h1
    @State private var style: ChartStyle = .candles
    @State private var indicator: ChartIndicator = .volume
    @State private var anchor = Date()

    private let axisLabelWidth: CGFloat = 58

    private var series: [PriceCandle] {
        let live = prices.price(symbol)
        if var real = model.candles[timeframe], let last = real.last {
            // Pin the forming candle to the live tick (only a real feed — never graft demo onto market data).
            if prices.isLive, live > 0 {
                real[real.count - 1] = PriceCandle(t: last.t, o: last.o, h: max(last.h, live),
                                                   l: min(last.l, live), c: live, v: last.v)
            }
            return real
        }
        if model.loading.contains(timeframe) { return [] }   // brief placeholder, not a fake series
        return SyntheticMarket.intraday(symbol: symbol, timeframe: timeframe, mid: live, now: anchor)
    }

    private var candleSource: CandleSource {
        model.candles[timeframe] == nil ? .synthetic : model.candleSource(timeframe)
    }

    private func barWidth(_ count: Int) -> CGFloat { max(2, min(9, 250.0 / Double(max(count, 1)))) }
    private var xDomain: ClosedRange<Double> { -0.5...(Double(max(series.count, 1)) - 0.5) }

    private var periodDelta: Double? {
        guard let f = series.first?.c, let l = series.last?.c, f > 0 else { return nil }
        return (l - f) / f * 100
    }

    var body: some View {
        let candles = series
        VStack(alignment: .leading, spacing: Spacing.sm) {
            controlsRow
            HStack(spacing: Spacing.sm) {
                if let pct = periodDelta { deltaChip(pct) }
                Spacer(minLength: Spacing.xs)
                sourceCaption
            }
            CandleChart(candles: candles, style: style, axisLabelWidth: axisLabelWidth)
            if indicator != .none, !candles.isEmpty {
                indicatorPanel(candles)
            }
        }
        .task(id: timeframe) { await model.loadChart(timeframe) }   // real klines per tab
    }

    // MARK: Controls

    private var controlsRow: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Timeframe.allCases) { tf in
                Button { timeframe = tf } label: {
                    Text(tf.title)
                        .font(BrandFont.footnote.weight(.medium))
                        .foregroundStyle(timeframe == tf ? theme.background : theme.textPrimary)
                        .frame(minWidth: 38, minHeight: 28)
                        .background(timeframe == tf ? theme.textPrimary : theme.fill,
                                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }
            Spacer(minLength: Spacing.xs)
            Button { style = (style == .candles ? .line : .candles) } label: {
                Image(systemName: style.icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 34, height: 28)
                    .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            Menu {
                Picker("Индикатор", selection: $indicator) {
                    ForEach(ChartIndicator.allCases) { ind in Text(ind.title).tag(ind) }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 12, weight: .regular))
                    Text(indicator == .none ? "Индик." : indicator.title).font(BrandFont.micro)
                }
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, Spacing.sm)
                .frame(height: 28)
                .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            }
        }
    }

    private func deltaChip(_ pct: Double) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text("\(CryptoFormat.pct(pct)) за \(timeframe.title)").font(BrandFont.footnote.weight(.medium))
                .monospacedDigit()
        }
        .foregroundStyle(pct >= 0 ? theme.success : theme.danger)
    }

    /// Candle provenance: «Binance · 1Ч свечи» for market data, «синтетика» (amber) otherwise.
    @ViewBuilder private var sourceCaption: some View {
        if model.loading.contains(timeframe) && model.candles[timeframe] == nil {
            ProgressView().controlSize(.mini)
        } else {
            let synthetic = candleSource == .synthetic
            HStack(spacing: 4) {
                Image(systemName: synthetic ? "exclamationmark.triangle" : "chart.bar.xaxis")
                    .font(.system(size: 9, weight: .semibold))
                Text(synthetic ? "синтетика" : "\(candleSource.caption) · свечи \(timeframe.title)")
                    .font(BrandFont.micro)
            }
            .foregroundStyle(synthetic ? theme.warning : theme.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(synthetic ? "Синтетический график, нет рыночных свечей"
                                          : "Свечи \(candleSource.caption), таймфрейм \(timeframe.title)")
        }
    }

    // MARK: Indicator sub-panel (shares the price panel's x-scale + axis width)

    @ViewBuilder private func indicatorPanel(_ candles: [PriceCandle]) -> some View {
        switch indicator {
        case .none:   EmptyView()
        case .volume: volumePanel(candles)
        case .macd:   macdPanel(candles)
        }
    }

    private func volumePanel(_ candles: [PriceCandle]) -> some View {
        let bars = TechnicalIndicators.volume(candles, symbol: symbol)
        let maxV = bars.map(\.value).max() ?? 1
        let bw = barWidth(candles.count)
        return Chart(bars) { bar in
            BarMark(x: .value("i", bar.index),
                    y: .value("v", bar.value),
                    width: .fixed(bw))
                .foregroundStyle((bar.up ? theme.success : theme.danger).opacity(0.5))
                .cornerRadius(1)
        }
        .chartYScale(domain: 0...(maxV * 1.15))
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { _ in
                AxisValueLabel { Color.clear.frame(width: axisLabelWidth, height: 1) }
            }
        }
        .frame(height: 58)
        .overlay(alignment: .topLeading) {
            Text("Объём").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
        }
    }

    private func macdPanel(_ candles: [PriceCandle]) -> some View {
        let points = TechnicalIndicators.macd(candles)
        let bw = barWidth(candles.count)
        let accent = theme.textPrimary
        return Chart {
            ForEach(points) { p in
                BarMark(x: .value("i", p.index),
                        y: .value("h", p.histogram),
                        width: .fixed(bw))
                    .foregroundStyle((p.histogram >= 0 ? theme.success : theme.danger).opacity(0.45))
            }
            ForEach(points) { p in
                LineMark(x: .value("i", p.index), y: .value("macd", p.macd), series: .value("s", "MACD"))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
            ForEach(points) { p in
                LineMark(x: .value("i", p.index), y: .value("signal", p.signal), series: .value("s", "Signal"))
                    .foregroundStyle(theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.4))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { _ in
                AxisValueLabel { Color.clear.frame(width: axisLabelWidth, height: 1) }
            }
        }
        .frame(height: 58)
        .overlay(alignment: .topLeading) {
            Text("MACD 12·26·9").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
        }
    }
}
