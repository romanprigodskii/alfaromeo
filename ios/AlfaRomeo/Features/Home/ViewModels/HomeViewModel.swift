import Foundation
import Observation

/// Loads and holds the profile-scoped dashboard (§9.1) plus the live crypto price stream (§11.4).
///
/// One fan-out of ``APIClient`` calls builds a ``HomeDashboard``; ``PriceSocket`` ticks then update
/// ``livePrices`` so the ₽-equivalent and crypto valuation move in real time. The loader keeps the
/// last good snapshot as a cache: a failed *refresh* keeps content on screen and raises a banner
/// (§10.2 «ошибка обновления (кэш + плашка)»); only a first load with no cache hard-fails.
@MainActor
@Observable
final class HomeViewModel {
    enum Phase: Equatable { case idle, loading, loaded, failed }

    private(set) var phase: Phase = .idle
    private(set) var dashboard: HomeDashboard?
    private(set) var refreshFailed = false
    var livePrices: [String: Double] = [:]

    private var priceSocket: PriceSocket?
    private static let trackedAssets = ["BTC", "ETH", "USDT", "SOL", "TON"]

    /// Demo-only: a short delay on the *first* load per profile so the skeleton state is observable
    /// against the instant ``MockAPIClient`` (§10.2). Set to `.zero` for a real backend.
    var firstLoadDelay: Duration = .milliseconds(650)

    /// Skeletons show only when there is nothing cached yet.
    var isInitialLoading: Bool { phase == .loading && dashboard == nil }

    // MARK: - Load

    /// Fetch the dashboard for the active profile. Re-run on every profile switch via `.task(id:)`,
    /// so switching re-scopes all data to the new `profileId` (§5.3).
    func load(api: any APIClient, session: AppSession) async {
        guard let profile = session.activeProfile else { return }
        let pid = profile.id

        // Switching profile → drop stale content so skeletons show under the NEW header (§5.3).
        if dashboard?.profileId != pid { dashboard = nil }
        let firstLoad = dashboard == nil

        phase = .loading
        refreshFailed = false
        if firstLoad, firstLoadDelay > .zero {
            try? await Task.sleep(for: firstLoadDelay)   // demo: surface the skeleton state
        }

        do {
            async let accounts = api.accounts(profileId: pid)
            async let cards = api.cards(profileId: pid)
            async let cardOrders = api.cardOrders(profileId: pid)
            async let wallets = api.cryptoWallets(profileId: pid)
            async let deposits = api.deposits(profileId: pid)
            async let mobile = api.mobilePlan(profileId: pid)
            async let subscription = api.subscription(profileId: pid)
            async let prices = api.prices(assets: Self.trackedAssets)

            let snapshot = Dictionary(
                try await prices.map { ($0.asset.uppercased(), $0.price) },
                uniquingKeysWith: { first, _ in first }
            )
            let baseTier = try await subscription.tier
            let built = HomeDashboard(
                profileId: pid,
                profileType: profile.type,
                accounts: try await accounts,
                cards: try await cards,
                cardOrders: try await cardOrders,
                wallets: try await wallets,
                deposits: try await deposits,
                mobilePlan: try await mobile,
                tier: session.currentTier(for: pid, fallback: baseTier),
                priceSnapshot: snapshot
            )

            // A profile switch may have landed while we were loading — discard this stale result.
            guard session.activeProfile?.id == pid else { return }
            dashboard = built
            phase = .loaded
            refreshFailed = false
        } catch {
            if Task.isCancelled { return }          // superseded by a newer load — leave state alone
            if dashboard == nil {
                phase = .failed                     // hard fail: nothing to show
            } else {
                phase = .loaded
                refreshFailed = true                // kept cache + banner (§10.2)
            }
        }
    }

    // MARK: - Live prices (§11.4)

    /// Consume the mock ``PriceSocket`` for the view's lifetime; cancelled when the view disappears.
    func streamPrices() async {
        let socket = PriceSocket(source: .mock, assets: Self.trackedAssets)
        priceSocket = socket
        for await tick in socket.ticks() {
            livePrices[tick.asset.uppercased()] = tick.price
        }
        priceSocket = nil
    }
}
