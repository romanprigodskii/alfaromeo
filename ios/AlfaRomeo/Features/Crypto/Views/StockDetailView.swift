import SwiftUI

/// A Moscow Exchange instrument (§9.6 «Биржа» → «Акции»): live ISS quote, candles per timeframe
/// (1Д / 1Н / 1М / 1Г via ``MoexFeed``) on the shared ``CandleChart``, a source line, and the facts
/// that matter for the kind (bonds: % of nominal, yield, maturity). Buying is not in this version:
/// «Купить» opens a short sheet saying the brokerage account comes next.
struct StockDetailView: View {
    let secid: String

    @Environment(\.theme) private var theme
    @State private var feed = MoexFeed.shared
    @State private var timeframe: MoexTimeframe = .day
    @State private var showBuy = false

    var body: some View {
        if let inst = MoexInstrument.find(secid) {
            content(inst)
        } else {
            Text("Бумага не найдена")
                .font(BrandFont.bodyM)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.background.ignoresSafeArea())
        }
    }

    private func content(_ inst: MoexInstrument) -> some View {
        let quote = feed.quote(inst.secid)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header(inst, quote)
                chart(inst)
                facts(inst, quote)
                PriceAlertsSection(asset: inst.secid, market: .moex, assetTitle: inst.title,
                                   currentPrice: quote?.price, isLive: feed.isLive)
                PrimaryButton(title: "Купить") { showBuy = true }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle(inst.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await feed.poll() }
        .task(id: timeframe) {
            // Candles refresh every minute while the screen is open (quotes poll every 15 s above).
            while !Task.isCancelled {
                await feed.loadCandles(inst, timeframe)
                // A demo walk means ISS did not answer: retry soon instead of in a minute.
                try? await Task.sleep(for: .seconds(feed.seriesIsDemo(inst.secid, timeframe) ? 5 : 60))
            }
        }
        .bottomSheet(isPresented: $showBuy, detents: [.medium]) { buySheet(inst) }
    }

    // MARK: Header

    private func header(_ inst: MoexInstrument, _ quote: MoexQuote?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                GlyphCircle(text: inst.monogram, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(inst.title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text("\(inst.ticker) · \(inst.board)")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }
            }
            if let quote {
                Text(MoneyFormat.fiat(quote.price))
                    .font(BrandFont.amount)
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: quote.price)
                HStack(spacing: Spacing.sm) {
                    MoexChangeText(pct: quote.changePct, suffix: " за день")
                    Text(inst.unitNote).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
            }
            MoexSourceBadge(feed: feed)
        }
    }

    // MARK: Chart

    private func chart(_ inst: MoexInstrument) -> some View {
        let series = feed.series(inst.secid, timeframe) ?? []
        let loading = series.isEmpty && feed.isLoading(inst.secid, timeframe)
        let demo = feed.seriesIsDemo(inst.secid, timeframe)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                ForEach(MoexTimeframe.allCases) { tf in
                    Button { timeframe = tf } label: {
                        Text(tf.title)
                            .font(BrandFont.footnote.weight(.medium))
                            .foregroundStyle(timeframe == tf ? theme.background : theme.textPrimary)
                            .frame(minWidth: 44, minHeight: 30)
                            .background(timeframe == tf ? theme.textPrimary : theme.fill,
                                        in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(timeframe == tf ? .isSelected : [])
                }
                Spacer(minLength: 0)
                if let pct = periodDelta(series) { MoexChangeText(pct: pct, font: BrandFont.footnote) }
            }
            CandleChart(candles: series, style: timeframe == .year ? .line : .candles)
                .opacity(loading ? 0.5 : 1)
            Text(demo ? "Демо-график: нет связи с MOEX" : "Источник: MOEX ISS · \(timeframe.caption) · время МСК")
                .font(BrandFont.footnote)
                .foregroundStyle(demo ? theme.warning : theme.textSecondary)
        }
    }

    private func periodDelta(_ s: [PriceCandle]) -> Double? {
        guard let f = s.first?.o, let l = s.last?.c, f > 0 else { return nil }
        return (l - f) / f * 100
    }

    // MARK: Facts

    private func facts(_ inst: MoexInstrument, _ quote: MoexQuote?) -> some View {
        GroupedSection("О бумаге") {
            ListRow(title: "Тикер", value: inst.ticker)
            ListRow(title: "Режим торгов", value: inst.board)
            if inst.kind == .bond {
                if let p = quote?.pricePct {
                    ListRow(title: "Цена, % от номинала", value: MoneyFormat.percent(p, minFractionDigits: 2, maxFractionDigits: 3))
                }
                if let y = quote?.yield {
                    ListRow(title: "Доходность к погашению", value: MoneyFormat.percent(y, minFractionDigits: 2, maxFractionDigits: 2))
                }
                ListRow(title: "Номинал", value: MoneyFormat.fiat(inst.faceValue))
                if let m = inst.maturity { ListRow(title: "Погашение", value: m) }
            }
            if let t = quote?.updateTime, !t.isEmpty {
                ListRow(title: "Последняя сделка", value: "\(t.prefix(5)) МСК")
            }
        }
    }

    // MARK: Buy

    private func buySheet(_: MoexInstrument) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            GlyphCircle(systemImage: "briefcase", size: 48)
            Text("Брокерский счёт откроется в следующей версии")
                .font(BrandFont.title2)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Пока здесь можно следить за котировками Мосбиржи. Покупка акций и ОФЗ появится вместе с брокерским счётом.")
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            PrimaryButton(title: "Понятно") { showBuy = false }
        }
    }
}

#Preview {
    NavigationStack { StockDetailView(secid: "SBER") }
        .environment(\.theme, .default)
}
