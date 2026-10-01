import SwiftUI

/// Выгода (§9.3): the cashback hub. A balance hero plus entries to the three cashback screens
/// («Выбор категорий», «Супер-кэшбек», «Предложения / партнёры») and the existing tier comparison
/// («Подписка/Тариф», §0.6 / §4). Subtitles reflect the live tier + ``BenefitsStore`` selection.
///
/// No section route enum: this view lives inside the Выгода section's `NavigationStack` (provided by
/// ``SectionScaffold``), so the entries push via destination-based `NavigationLink`, no `Router`.
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                hero
                entries
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .contentMargins(.bottom, 96, for: .scrollContent)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Hero: accrued cashback + tier (the one main amount on the screen, no card)

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Накоплено кэшбека").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Spacer()
                Badge(kind: .text(effectiveTier.shortLabel))
            }
            AmountText(amount: store.cashbackBalance, size: 40, splitsKopecks: true)
            Text("\(MoneyFormat.percent(store.monthOverMonthDeltaPct, sign: .always)) к прошлому месяцу")
                .font(BrandFont.subheadline).foregroundStyle(theme.success)
        }
    }

    // MARK: Entries

    private var entries: some View {
        GroupedSection {
            NavigationLink { CategorySelectionView() } label: {
                ListRow(icon: "square.grid.2x2", title: "Категории",
                        subtitle: categorySubtitle, showsChevron: true)
            }
            .buttonStyle(.row)

            NavigationLink { SuperCashbackView() } label: {
                ListRow(icon: "percent", title: "Супер-кэшбек",
                        subtitle: superSubtitle, showsChevron: true)
            }
            .buttonStyle(.row)

            NavigationLink { PartnerOffersView() } label: {
                ListRow(icon: "bag", title: "Партнёры",
                        subtitle: "\(PartnerOffer.visible(for: entitlements).count) предложений",
                        showsChevron: true)
            }
            .buttonStyle(.row)

            NavigationLink { SubscriptionView() } label: {
                ListRow(icon: "crown", title: "Подписка и тариф",
                        subtitle: "Текущий: \(effectiveTier.shortLabel)", showsChevron: true)
            }
            .buttonStyle(.row)
        }
    }

    // MARK: Dynamic subtitles

    private var categorySubtitle: String {
        let n = store.selectedCount(profileId: profileId)
        if entitlements.allCashbackCategories { return "Активно: \(n), без лимита" }
        return "Активно: \(n) из \(store.categoryLimit(for: entitlements))"
    }

    private var superSubtitle: String {
        guard store.isSuperCashbackUnlocked(for: entitlements) else { return "Доступно на Pro" }
        if let id = store.superCashbackCategoryId(profileId: profileId),
           let c = CashbackCategory.lookup(id) {
            return "\(c.name): \(CashbackCategory.pct(c.superRate ?? 0))"
        }
        return "Категория не выбрана"
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
