import SwiftUI
import Charts

/// The price panel of the trading chart (§9.6 / §11.4): a smooth area/line for the trend, or OHLC
/// candlesticks (зелёная вверх / красная вниз) on the cold palette. The x-axis is an explicit integer
/// domain and the trailing y-axis labels are a fixed width, so an indicator sub-panel below
/// (``TradingChartView``) lines up pixel-for-pixel on the same x-scale. Used inside ``TradingChartView``.
struct CandleChart: View {
    let candles: [PriceCandle]
    var style: ChartStyle = .candles
    var height: CGFloat = 232
    /// Fixed trailing y-axis label width — must match the indicator panel so plot areas align.
    var axisLabelWidth: CGFloat = 58

    @Environment(\.theme) private var theme

    private var indexed: [(offset: Int, element: PriceCandle)] {
        Array(candles.enumerated()).map { (offset: $0.offset, element: $0.element) }
    }
    private var lows: [Double] { candles.map(\.l) }
    private var highs: [Double] { candles.map(\.h) }
    private var domain: ClosedRange<Double> {
        let lo = (lows.min() ?? 0) * 0.997
        let hi = (highs.max() ?? 1) * 1.003
        return lo < hi ? lo...hi : (lo...(lo + 1))
    }
    private var xDomain: ClosedRange<Double> { -0.5...(Double(max(candles.count, 1)) - 0.5) }
    private var barWidth: CGFloat { max(2, min(9, 250.0 / Double(max(candles.count, 1)))) }
    private var line: Color { theme.accentCrypto.last ?? theme.accent }

    var body: some View {
        Group {
            if candles.isEmpty { placeholder } else { chart }
        }
        .frame(height: height)
    }

    private var chart: some View {
        Chart {
            ForEach(indexed, id: \.offset) { item in
                let c = item.element
                if style == .line {
                    AreaMark(x: .value("i", item.offset),
                             yStart: .value("min", domain.lowerBound),
                             yEnd: .value("₽", c.c))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.linearGradient(colors: [line.opacity(0.28), line.opacity(0.02)],
                                                          startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("i", item.offset), y: .value("₽", c.c))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(theme.cryptoGradient)
                } else {
                    RuleMark(x: .value("i", item.offset),
                             yStart: .value("low", c.l), yEnd: .value("high", c.h))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(color(for: c))
                    BarMark(x: .value("i", item.offset),
                            yStart: .value("open", min(c.o, c.c)),
                            yEnd: .value("close", max(c.o, c.c)),
                            width: .fixed(barWidth))
                        .foregroundStyle(color(for: c))
                        .cornerRadius(1)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(theme.border.opacity(0.6))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(CryptoFormat.compactRub(v))
                            .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                            .frame(width: axisLabelWidth, alignment: .leading)
                    }
                }
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(theme.elevated)
            ProgressView().tint(theme.accentCrypto.first ?? theme.accent)
        }
    }

    private func color(for c: PriceCandle) -> Color { c.c >= c.o ? theme.success : theme.danger }
}

#Preview {
    CandleChart(candles: MockData.candles("BTC", range: .week), style: .candles)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.resolve(for: nil, scheme: .dark).background)
        .environment(\.theme, .resolve(for: nil, scheme: .dark))
}
