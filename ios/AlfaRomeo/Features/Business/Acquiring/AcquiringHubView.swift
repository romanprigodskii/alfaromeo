import SwiftUI

// MARK: - Эквайринг hub (§8.2)
// Root screen pushed as the «Эквайринг» business-tab root. It does NOT own a
// NavigationStack — it registers destinations on the ambient stack and reads
// the ambient Router.
struct AcquiringHubView: View {
    @Environment(Router.self) private var router
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var store = AcquiringStore.shared
    @State private var prices = LivePriceService.shared

    private var profileId: String { session.activeProfile?.id ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                if store.loadFailed {
                    errorBlock
                } else if !store.didLoad && store.recentRevenue.isEmpty {
                    loadingBlock
                } else {
                    heroBlock
                    quickActionsBlock
                    channelsSection
                    pointsSection
                    recentSection
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .navigationTitle("Эквайринг")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        .task(id: profileId) { await store.load(api: api, profileId: profileId) }
        .task { await prices.start() }
    }

    // MARK: - States

    private var loadingBlock: some View {
        GroupedSection {
            ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
        }
        .accessibilityLabel("Загружаем эквайринг")
    }

    private var errorBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Не удалось загрузить эквайринг")
                    .font(BrandFont.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            SecondaryButton(title: "Повторить") {
                Task { await store.load(api: api, profileId: profileId, force: true) }
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - 1) Revenue hero

    private var heroBlock: some View {
        RevenueHeroCard(summary: store.summary(), isLive: prices.isLive) {
            router.push(AcquiringRoute.revenue)
        }
    }

    // MARK: - 2) Quick actions

    private var quickActionsBlock: some View {
        QuickActionRow {
            QuickActionButton("Ссылка", systemImage: "link") {
                router.push(AcquiringRoute.createLink(.link))
            }
            QuickActionButton("QR", systemImage: "qrcode") {
                router.push(AcquiringRoute.createLink(.qr))
            }
            QuickActionButton("Принять", systemImage: "creditcard") {
                router.push(AcquiringRoute.acceptPayment)
            }
            QuickActionButton("Отчёт", systemImage: "chart.bar") {
                router.push(AcquiringRoute.revenue)
            }
        }
    }

    // MARK: - 3) Channels

    private var channelsSection: some View {
        GroupedSection("Каналы приёма") {
            ChannelCard(channel: .online, liveRate: nil, isLive: prices.isLive) {
                router.push(AcquiringRoute.createLink(.link))
            }
            ChannelCard(channel: .offline, liveRate: nil, isLive: prices.isLive) {
                router.push(AcquiringRoute.createLink(.qr))
            }
            ChannelCard(channel: .crypto, liveRate: store.rubRate(asset: "USDT"), isLive: prices.isLive) {
                router.push(AcquiringRoute.acceptPayment)
            }
        }
    }

    // MARK: - 4) Configured points

    private var pointsSection: some View {
        GroupedSection("Настроенные точки") {
            if store.points.isEmpty {
                Text("Точки приёма ещё не настроены")
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            } else {
                ForEach(store.points) { point in
                    ListRow(
                        icon: iconFor(point.type),
                        title: point.label ?? typeTitle(point.type),
                        subtitle: typeSubtitle(point.type)
                    )
                }
            }
        }
    }

    // MARK: - 5) Recent revenue

    private var recentSection: some View {
        GroupedSection("Последние поступления", actionTitle: "Все",
                       action: { router.push(AcquiringRoute.revenue) }) {
            if store.recentRevenue.isEmpty {
                Text("Пока нет поступлений")
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Spacing.rowMinHeight, alignment: .leading)
            } else {
                ForEach(store.recentRevenue) { entry in
                    RevenueEntryRow(entry: entry)
                }
            }
        }
    }
}

// MARK: - AcquiringType presentation (file-private)

private func iconFor(_ type: AcquiringType) -> String {
    switch type {
    case .online: return "globe"
    case .terminal: return "creditcard"
    case .qr: return "qrcode"
    case .link: return "link"
    case .crypto: return "bitcoinsign"
    }
}

private func typeTitle(_ type: AcquiringType) -> String {
    switch type {
    case .online: return "Интернет-эквайринг"
    case .terminal: return "Терминал на кассе"
    case .qr: return "Приём по QR"
    case .link: return "Платёжная ссылка"
    case .crypto: return "Крипто-приём · авто-₽"
    }
}

private func typeSubtitle(_ type: AcquiringType) -> String {
    switch type {
    case .online: return "Приём оплат на сайте и в приложении"
    case .terminal: return "Карты и СБП на офлайн-кассе"
    case .qr: return "Оплата по QR-коду СБП"
    case .link: return "Разовая ссылка для оплаты"
    case .crypto: return "USDT и USDC с конвертацией в ₽"
    }
}

// MARK: - Preview

private struct AcquiringHubView_PreviewHost: View {
    var body: some View {
        let session = AppSession.mockAuthenticated()
        if let biz = session.profiles.first(where: { $0.type == .business }) {
            session.switchProfile(biz)
        }
        return NavigationStack {
            AcquiringHubView()
                .navigationDestination(for: AcquiringRoute.self) { $0.destination }
        }
        .themeProvider(profileType: .business)
        .environment(session)
        .environment(Router())
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview {
    AcquiringHubView_PreviewHost()
}
