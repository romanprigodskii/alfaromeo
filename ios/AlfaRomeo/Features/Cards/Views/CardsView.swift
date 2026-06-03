import SwiftUI

/// Карты профиля (§6.3): карусель карт (тап → детейл), раздел «в доставке» (тап → трекинг), и
/// тир-гейтнутый заказ. Лимит карт по тиру (Base 1 / Pro 3 / Infinite ∞) — при попытке создать карту
/// сверх лимита показывается мягкая ``UpsellCard``; на Pro+ заказ проходит. Одноразовые карты не
/// занимают лимит и доступны всегда.
struct CardsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store = CardsStore.shared
    @State private var visibleCardId: String?
    /// Measured content width → deterministic carousel card sizing (CardFaceView is GeometryReader-
    /// based and has no intrinsic size, so it must be given a definite width).
    @State private var contentWidth: CGFloat = 360

    private var cardWidth: CGFloat { max(contentWidth - Spacing.lg * 2, 0) }
    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var ent: Entitlements { Entitlements.make(for: effectiveTier) }
    private var primaryCount: Int { store.primaryCards.count }
    private var canAdd: Bool { ent.canAddCard(currentCount: primaryCount) }

    private var recommendedTier: Tier {
        let track = Tier.track(forBusiness: session.isBusinessMode)
        return track[min(effectiveTier.rank + 1, track.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                limitLine

                if store.cards.isEmpty {
                    if store.loadFailed { errorState }
                    else if store.didLoad { emptyState }
                } else {
                    carousel
                    if store.cards.count > 1 { pageDots }
                }

                inFlightSection
                orderActions

                Text("Одноразовые карты не занимают лимит тарифа — это эфемерные токены безопасности.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { geo in
                Color.clear.preference(key: CardsWidthKey.self, value: geo.size.width)
            })
        }
        .onPreferenceChange(CardsWidthKey.self) { width in
            if width > 0 { contentWidth = width }
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Карты профиля")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: store.cards)
        .animation(reduceMotion ? nil : Motion.snappy, value: effectiveTier)
        .task {
            await store.load(api: api, profileId: profileId)
            if visibleCardId == nil { visibleCardId = store.defaultCard?.id }
        }
    }

    // MARK: Header

    private var limitLine: some View {
        Text("Лимит карт на тарифе \(effectiveTier.displayName): \(ent.maxCardsLabel). Сейчас: \(primaryCount).")
            .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
            .padding(.horizontal, Spacing.lg)
    }

    // MARK: Carousel

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Spacing.md) {
                ForEach(store.cards) { card in
                    Button { router.push(CardsRoute.detail(cardId: card.id)) } label: {
                        CardFaceView(card: card).frame(width: cardWidth)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .id(card.id)
                }
            }
            .scrollTargetLayout()
        }
        .frame(height: cardWidth / 1.586)
        .contentMargins(.horizontal, Spacing.lg, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleCardId)
    }

    private var pageDots: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(store.cards) { card in
                Circle()
                    .fill(card.id == visibleCardId ? theme.accent : theme.border)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : Motion.snappy, value: visibleCardId)
    }

    // MARK: In-flight delivery

    @ViewBuilder
    private var inFlightSection: some View {
        let orders = store.inFlightOrders
        if !orders.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("В доставке").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(orders.enumerated()), id: \.element.id) { i, order in
                            Button { router.push(CardsRoute.tracking(orderId: order.id)) } label: {
                                HStack {
                                    ListRow(icon: "shippingbox.fill",
                                            title: "Пластиковая карта",
                                            subtitle: "Трек \(order.tracking)")
                                    StatusPill(status: order.status == .delivered ? .success : .processing,
                                               text: order.status.title)
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }.buttonStyle(.plain)
                            if i < orders.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: Order actions

    private var orderActions: some View {
        VStack(spacing: Spacing.md) {
            if canAdd {
                PrimaryButton(title: "Заказать карту", icon: "plus") {
                    router.push(CardsRoute.order)
                }
            } else {
                UpsellCard(
                    title: "Лимит карт на тарифе \(effectiveTier.shortLabel)",
                    message: "На \(effectiveTier.displayName) доступно карт: \(ent.maxCardsLabel). Повысьте тариф, чтобы заказать ещё.",
                    recommendedTier: recommendedTier)
            }
            SecondaryButton(title: "Выпустить одноразовую", icon: "flame") {
                store.orderPreset = .disposable
                router.push(CardsRoute.order)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: Empty

    private var emptyState: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Image(systemName: "creditcard").font(.system(size: 28)).foregroundStyle(theme.accent)
                Text("У вас пока нет карт").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Закажите карту — виртуальная выпускается мгновенно и сразу доступна для оплат.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: Error (criterion 7 «ошибки»)

    private var errorState: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Не удалось загрузить карты", systemImage: "exclamationmark.triangle")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Проверьте соединение и попробуйте снова.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                SecondaryButton(title: "Повторить", icon: "arrow.clockwise") {
                    Task { await store.load(api: api, profileId: profileId, force: true) }
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}

/// Captures the scroll content width so the carousel can size its cards deterministically.
private struct CardsWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
