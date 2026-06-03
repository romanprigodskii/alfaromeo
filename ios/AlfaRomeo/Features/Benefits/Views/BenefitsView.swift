import SwiftUI

/// Выгода (§9.3) — the cashback hub. A balance hero plus entries to the three cashback screens
/// («Выбор категорий», «Супер-кэшбек», «Предложения / партнёры») and the existing tier comparison
/// («Подписка/Тариф», §0.6 / §4). Subtitles reflect the live tier + ``BenefitsStore`` selection.
///
/// No section route enum: this view lives inside the Выгода section's `NavigationStack` (provided by
/// ``SectionScaffold``), so the entries push via destination-based `NavigationLink` — no `Router`.
struct BenefitsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var baseTier: Tier = .base
    private let store = BenefitsStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: baseTier) }
    private var entitlements: Entitlements { Entitlements.make(for: effectiveTier) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                entries
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Hero — accrued cashback + tier

    private var hero: some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Накоплено кэшбека").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Badge(kind: .text(effectiveTier.shortLabel), tint: theme.accent)
                }
                AmountText(amount: store.cashbackBalance, size: 34)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(theme.success)
                    Text("На +\(Int(store.monthOverMonthDeltaPct))% больше, чем в прошлом месяце")
                        .font(BrandFont.caption).foregroundStyle(theme.success)
                }
            }
        }
    }

    // MARK: Entries

    private var entries: some View {
        SurfaceCard(padding: Spacing.sm) {
            VStack(spacing: 0) {
                NavigationLink { CategorySelectionView() } label: {
                    ListRow(icon: "square.grid.2x2.fill", title: "Выбор категорий",
                            subtitle: categorySubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().overlay(theme.border)

                NavigationLink { SuperCashbackView() } label: {
                    ListRow(icon: "sparkles", title: "Супер-кэшбек",
                            subtitle: superSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().overlay(theme.border)

                NavigationLink { PartnerOffersView() } label: {
                    ListRow(icon: "bag.fill", title: "Предложения и партнёры",
                            subtitle: "\(PartnerOffer.visible(for: entitlements).count) предложений",
                            showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider().overlay(theme.border)

                NavigationLink { SubscriptionView() } label: {
                    ListRow(icon: "crown.fill", title: "Подписка и тариф",
                            subtitle: "Сравнить Base · Pro · Infinite (§4)", showsChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Dynamic subtitles

    private var categorySubtitle: String {
        let n = store.selectedCount(profileId: profileId)
        if entitlements.allCashbackCategories { return "Активно: \(n) · без лимита" }
        return "Активно: \(n) из \(store.categoryLimit(for: entitlements))"
    }

    private var superSubtitle: String {
        guard store.isSuperCashbackUnlocked(for: entitlements) else { return "Доступно на Pro" }
        if let id = store.superCashbackCategoryId(profileId: profileId),
           let c = CashbackCategory.lookup(id) {
            return "\(c.name): \(CashbackCategory.pct(c.superRate ?? 0))"
        }
        return "Повышенные ставки"
    }
}

#Preview {
    NavigationStack {
        BenefitsView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
}
