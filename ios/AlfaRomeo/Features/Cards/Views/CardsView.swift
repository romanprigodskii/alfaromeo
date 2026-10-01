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

    private var cardWidth: CGFloat { max(contentWidth - Spacing.screen * 2, 0) }
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                if store.cards.isEmpty {
                    if store.loadFailed { errorState }
                    else if store.didLoad { emptyState }
                } else {
                    VStack(spacing: Spacing.md) {
                        carousel
                        if store.cards.count > 1 { pageDots }
                    }
                }

                inFlightSection
                orderActions
            }
            .padding(.top, Spacing.md)
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

    // MARK: Carousel

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: Spacing.sm + 4) {
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
        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleCardId)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(store.cards) { card in
                Circle()
                    .fill(card.id == visibleCardId ? theme.textPrimary : theme.border)
                    .frame(width: 6, height: 6)
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
            GroupedSection("В доставке") {
                ForEach(orders) { order in
                    Button { router.push(CardsRoute.tracking(orderId: order.id)) } label: {
                        HStack(spacing: Spacing.sm) {
                            ListRow(icon: "shippingbox",
                                    title: "Пластиковая карта",
                                    subtitle: "Трек \(order.tracking)")
                            StatusPill(status: order.status == .delivered ? .success : .processing,
                                       text: order.status.title)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .buttonStyle(.row)
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    // MARK: Order actions

    private var orderActions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            if canAdd {
                PrimaryButton(title: "Заказать карту") {
                    router.push(CardsRoute.order)
                }
            } else {
                UpsellCard(
                    title: "Лимит карт на тарифе \(effectiveTier.shortLabel)",
                    message: "На \(effectiveTier.displayName) доступно карт: \(ent.maxCardsLabel). Повысьте тариф, чтобы заказать ещё.",
                    recommendedTier: recommendedTier)
            }
            SecondaryButton(title: "Выпустить одноразовую") {
                store.orderPreset = .disposable
                router.push(CardsRoute.order)
            }
            Text("Лимит карт на тарифе \(effectiveTier.displayName): \(ent.maxCardsLabel), сейчас \(primaryCount). Одноразовые карты не занимают лимит.")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.md)
        }
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GlyphCircle(systemImage: "creditcard", size: 44)
            Text("Карт пока нет").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Виртуальная карта выпускается сразу после заказа и доступна для оплат.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: Error (criterion 7 «ошибки»)

    private var errorState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GlyphCircle(systemImage: "exclamationmark.triangle", size: 44)
            Text("Не удалось загрузить карты").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text("Проверьте соединение и попробуйте снова.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            SecondaryButton(title: "Повторить") {
                Task { await store.load(api: api, profileId: profileId, force: true) }
            }
            .padding(.top, Spacing.xs)
        }
        .padding(.horizontal, Spacing.screen)
    }
}

/// Captures the scroll content width so the carousel can size its cards deterministically.
private struct CardsWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
