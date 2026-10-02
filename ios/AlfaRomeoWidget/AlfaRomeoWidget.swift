import SwiftUI
import WidgetKit

/// Виджет «Курс и баланс»: BTC (и ETH в среднем размере) в ₽ по курсу ЦБ плюс общий баланс, который
/// приложение кладёт в App Group при расчёте «Главной». Цены тянутся прямо отсюда, раз в 15 минут.
@main
struct AlfaRomeoWidgetBundle: WidgetBundle {
    var body: some Widget {
        RatesBalanceWidget()
    }
}

struct RatesBalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.kind, provider: RatesProvider()) { entry in
            RatesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Курс и баланс")
        .description("Биткоин и эфир в рублях по курсу ЦБ и общий баланс. Обновляется каждые 15 минут.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension RatesEntry: TimelineEntry {}

struct RatesProvider: TimelineProvider {
    private static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> RatesEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (RatesEntry) -> Void) {
        if context.isPreview {
            completion(.sample)
            return
        }
        Task { completion(await Self.makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RatesEntry>) -> Void) {
        Task {
            let entry = await Self.makeEntry()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(Self.refresh))))
        }
    }

    private static func makeEntry() async -> RatesEntry {
        let result = await MarketFeed.load()
        return RatesEntry(date: .now, market: result.market, balance: BalanceSnapshot.read(),
                          marketIsCached: result.cached)
    }
}

struct RatesWidgetEntryView: View {
    let entry: RatesEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RatesWidgetView(entry: entry, size: family == .systemMedium ? .medium : .small)
            .containerBackground(WTheme(scheme).surface, for: .widget)
    }
}
