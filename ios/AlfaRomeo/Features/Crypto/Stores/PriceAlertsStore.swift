import Foundation
import Observation
import UIKit
import UserNotifications

/// A price alert (§9.6 «Биржа»): «сообщить, когда BTC станет выше 10 000 000 ₽». Crypto alerts read
/// ``LivePriceService``, Мосбиржа alerts read ``MoexFeed``; both only while the source is live.
struct PriceAlert: Identifiable, Codable, Hashable, Sendable {
    enum Direction: String, Codable, CaseIterable, Identifiable, Sendable {
        case above, below
        var id: String { rawValue }
        /// Segmented control label.
        var title: String { self == .above ? "Выше" : "Ниже" }
        /// Inline phrase: «выше 10 000 000 ₽».
        var phrase: String { self == .above ? "выше" : "ниже" }
        var icon: String { self == .above ? "arrow.up.right" : "arrow.down.right" }
    }

    /// Which feed prices the asset: crypto symbol (BTC) or a MOEX secid (SBER).
    enum Market: String, Codable, Sendable { case crypto, moex }

    var id = UUID()
    /// UPPERCASE crypto symbol or MOEX secid.
    let asset: String
    var market: Market = .crypto
    let direction: Direction
    let thresholdRub: Double
    let createdAt: Date
    var isActive = true
    var triggeredAt: Date?
    /// The live price that crossed the threshold.
    var triggeredPrice: Double?

    func isCrossed(by price: Double) -> Bool {
        direction == .above ? price >= thresholdRub : price <= thresholdRub
    }

    /// «Bitcoin», «Сбербанк»: for lists and notifications outside the asset's own screen.
    var assetTitle: String {
        switch market {
        case .crypto: return CryptoCatalog.asset(asset)?.name ?? asset
        case .moex:   return MoexInstrument.find(asset)?.title ?? asset
        }
    }
}

/// Price alerts: persisted in UserDefaults (Codable), evaluated on every live tick.
///
/// Evaluation observes ``LivePriceService/ticks`` and ``MoexFeed/snapshot`` (Observation) and runs only
/// while the matching source is live: a demo walk or a cached MOEX snapshot never fires an alert. On a
/// crossing the alert is marked triggered (one-shot), a local notification is posted (authorization is
/// requested on the first alert) and, in the foreground, an in-app ``banner`` shows for a few seconds.
@MainActor
@Observable
final class PriceAlertsStore {
    static let shared = PriceAlertsStore()

    private(set) var alerts: [PriceAlert] = []
    /// The alert that just fired while the app was active: the in-app banner.
    private(set) var banner: PriceAlert?

    private static let key = "AR_PRICE_ALERTS"
    @ObservationIgnored private var monitoring = false
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            alerts = saved
        }
    }

    // MARK: Reads

    /// Newest first: active alerts, then triggered ones.
    func alerts(for asset: String, market: PriceAlert.Market) -> [PriceAlert] {
        alerts.filter { $0.asset == asset.uppercased() && $0.market == market }.sorted(by: Self.order)
    }

    var allSorted: [PriceAlert] { alerts.sorted(by: Self.order) }

    func hasActive(_ market: PriceAlert.Market) -> Bool {
        alerts.contains { $0.isActive && $0.market == market }
    }

    /// Feeds the app-wide host must keep polling (as a `.task(id:)` key).
    var activeMarkets: Set<PriceAlert.Market> { Set(alerts.filter(\.isActive).map(\.market)) }

    private static func order(_ a: PriceAlert, _ b: PriceAlert) -> Bool {
        if a.isActive != b.isActive { return a.isActive }
        return (a.triggeredAt ?? a.createdAt) > (b.triggeredAt ?? b.createdAt)
    }

    // MARK: Writes

    @discardableResult
    func add(asset: String, market: PriceAlert.Market, direction: PriceAlert.Direction,
             thresholdRub: Double) -> PriceAlert {
        let alert = PriceAlert(asset: asset.uppercased(), market: market, direction: direction,
                               thresholdRub: thresholdRub, createdAt: Date())
        alerts.append(alert)
        save()
        Self.requestAuthorizationIfNeeded()
        evaluate(market)
        return alert
    }

    func delete(_ id: UUID) {
        alerts.removeAll { $0.id == id }
        if banner?.id == id { dismissBanner() }
        save()
    }

    func dismissBanner() {
        bannerTask?.cancel()
        banner = nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: Monitoring

    /// Start observing both price feeds. Idempotent; called by the app-wide host.
    func startMonitoring() {
        guard !monitoring else { return }
        monitoring = true
        trackCrypto()
        trackMoex()
        evaluate(.crypto)
        evaluate(.moex)
    }

    /// Keep the feeds the active alerts need running while the app is open, not only while a
    /// «Биржа» screen is visible. Cancelled and restarted by the host when the set changes.
    func keepFeedsWarm() async {
        let markets = activeMarkets
        if markets.contains(.crypto) { await LivePriceService.shared.start() }
        guard markets.contains(.moex) else { return }
        while !Task.isCancelled {
            await MoexFeed.shared.refresh()
            try? await Task.sleep(for: MoexFeed.pollInterval)
        }
    }

    private func trackCrypto() {
        withObservationTracking {
            let prices = LivePriceService.shared
            _ = prices.ticks
            _ = prices.source
        } onChange: { [weak self] in
            // `onChange` fires on willSet: hop so the new value is in place, then re-arm.
            Task { @MainActor [weak self] in
                self?.evaluate(.crypto)
                self?.trackCrypto()
            }
        }
    }

    private func trackMoex() {
        withObservationTracking {
            let feed = MoexFeed.shared
            _ = feed.snapshot
            _ = feed.source
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.evaluate(.moex)
                self?.trackMoex()
            }
        }
    }

    /// Live price for an alert, or nil when its source is not live (demo/cached never fires).
    private func livePrice(_ alert: PriceAlert) -> Double? {
        switch alert.market {
        case .crypto:
            let prices = LivePriceService.shared
            guard prices.isLive else { return nil }
            return prices.ticks[alert.asset]?.price
        case .moex:
            let feed = MoexFeed.shared
            guard feed.isLive else { return nil }
            return feed.quote(alert.asset)?.price
        }
    }

    private func sourceTitle(_ market: PriceAlert.Market) -> String {
        market == .crypto ? LivePriceService.shared.source.badgeTitle : "MOEX"
    }

    private func evaluate(_ market: PriceAlert.Market) {
        guard hasActive(market) else { return }
        var fired: [PriceAlert] = []
        for i in alerts.indices where alerts[i].isActive && alerts[i].market == market {
            guard let price = livePrice(alerts[i]), price > 0, alerts[i].isCrossed(by: price) else { continue }
            alerts[i].isActive = false
            alerts[i].triggeredAt = Date()
            alerts[i].triggeredPrice = price
            fired.append(alerts[i])
        }
        guard !fired.isEmpty else { return }
        save()
        let source = sourceTitle(market)
        for alert in fired { Self.notify(alert, source: source) }
        if UIApplication.shared.applicationState == .active, let last = fired.last { show(last) }
    }

    private func show(_ alert: PriceAlert) {
        bannerTask?.cancel()
        banner = alert
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, self?.banner?.id == alert.id else { return }
            self?.banner = nil
        }
    }

    // MARK: Notifications

    /// «Bitcoin выше 10 000 000 ₽»: shared by the notification and the in-app banner.
    static func headline(_ alert: PriceAlert) -> String {
        "\(alert.assetTitle) \(alert.direction.phrase) \(PriceAlert.rub(alert.thresholdRub))"
    }

    private static func requestAuthorizationIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    /// Posts an immediate local notification. iOS shows it when the app is in the background; in the
    /// foreground the system suppresses it (no delegate) and the in-app banner takes over.
    private static func notify(_ alert: PriceAlert, source: String) {
        guard SettingsStore.shared.notifyPush else { return }
        let content = UNMutableNotificationContent()
        content.title = headline(alert)
        let price = PriceAlert.rub(alert.triggeredPrice ?? alert.thresholdRub)
        content.body = "Сейчас \(price). Источник: \(source)."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "price-alert-\(alert.id.uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    #if DEBUG
    /// Screenshot seeding (`-ARShot priceAlerts`): replaces the book with the given alerts, in memory.
    func debugReplace(_ seeded: [PriceAlert], banner: PriceAlert? = nil) {
        alerts = seeded
        self.banner = banner
    }
    #endif
}
