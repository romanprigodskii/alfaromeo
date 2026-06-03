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
            VStack(alignment: .leading, spacing: Spacing.lg) {
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
            .padding(.horizontal, Spacing.lg)
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
        VStack {
            ProgressView()
                .tint(theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
        }
    }

    private var errorBlock: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.warning)
                    Text("Не удалось загрузить эквайринг")
                        .font(BrandFont.headline)
                        .foregroundStyle(theme.textPrimary)
                }
                Text("Проверьте соединение и попробуйте ещё раз.")
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
                SecondaryButton(title: "Повторить", icon: "arrow.clockwise") {
                    Task { await store.load(api: api, profileId: profileId, force: true) }
                }
            }
        }
    }

    // MARK: - 1) Revenue hero

    private var heroBlock: some View {
        RevenueHeroCard(summary: store.summary(), isLive: prices.isLive) {
            router.push(AcquiringRoute.revenue)
        }
    }

    // MARK: - 2) Quick actions

    private var quickActionsBlock: some View {
        HStack(spacing: Spacing.sm) {
            quickAction(title: "Ссылка", icon: "link") {
                router.push(AcquiringRoute.createLink(.link))
            }
            quickAction(title: "QR", icon: "qrcode") {
                router.push(AcquiringRoute.createLink(.qr))
            }
            quickAction(title: "Принять", icon: "creditcard.fill") {
                router.push(AcquiringRoute.acceptPayment)
            }
            quickAction(title: "Отчёт", icon: "chart.bar.fill") {
                router.push(AcquiringRoute.revenue)
            }
        }
    }

    private func quickAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.onAccent)
                }
                Text(title)
                    .font(BrandFont.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - 3) Channels

    private var channelsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Точки приёма")
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionHeader("Настроенные точки")
            SurfaceCard(padding: Spacing.sm) {
                if store.points.isEmpty {
                    Text("Точки приёма ещё не настроены")
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.points.enumerated()), id: \.element.id) { index, point in
                            if index > 0 {
                                Divider().overlay(theme.border)
                            }
                            ListRow(
                                icon: iconFor(point.type),
                                title: point.label ?? typeTitle(point.type),
                                subtitle: typeSubtitle(point.type)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5) Recent revenue

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionHeader("Последние поступления")
                Spacer()
                Button("Все") { router.push(AcquiringRoute.revenue) }
                    .font(BrandFont.callout.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
            SurfaceCard(padding: Spacing.sm) {
                if store.recentRevenue.isEmpty {
                    Text("Пока нет поступлений")
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.xs)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.recentRevenue.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider().overlay(theme.border)
                            }
                            RevenueEntryRow(entry: entry)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(BrandFont.headline)
            .foregroundStyle(theme.textPrimary)
    }
}

// MARK: - AcquiringType presentation (file-private)

private func iconFor(_ type: AcquiringType) -> String {
    switch type {
    case .online: return "globe"
    case .terminal: return "creditcard.fill"
    case .qr: return "qrcode"
    case .link: return "link"
    case .crypto: return "bitcoinsign.circle.fill"
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
    case .crypto: return "USDT · USDC → авто-конвертация в ₽"
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
