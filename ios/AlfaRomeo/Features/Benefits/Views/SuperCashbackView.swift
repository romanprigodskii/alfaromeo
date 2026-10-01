import SwiftUI

/// «Супер-кэшбек» (§9.3 / §4): an elevated cashback rate on one chosen category. A Pro+ feature: on
/// Base the screen shows a soft ``UpsellCard`` instead of the picker (§4, мягко, без тёмных
/// паттернов), never a hard block. Exactly one category is active at a time; state lives in
/// ``BenefitsStore``.
struct SuperCashbackView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var baseTier: Tier = .base
    private let store = BenefitsStore.shared

    /// Assumed monthly spend used to turn the rate uplift into a tangible «экономия» figure (mock).
    private let assumedMonthlySpend: Double = 40_000

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: baseTier) }
    private var entitlements: Entitlements { Entitlements.make(for: effectiveTier) }

    var body: some View {
        ScrollView {
            Group {
                if store.isSuperCashbackUnlocked(for: entitlements) {
                    unlockedBody
                } else {
                    lockedBody
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Супер-кэшбек")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Locked (Base): soft upsell, never blocked

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            Text("Повышенная ставка на одну категорию. Доступно на Pro и выше.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            UpsellCard(
                title: "Супер-кэшбек на Pro",
                message: "На Pro до 8 % на выбранную категорию вместо обычной ставки, на Infinite до 10 %.",
                recommendedTier: .pro
            )
        }
    }

    // MARK: Unlocked (Pro+)

    private var superEligible: [CashbackCategory] {
        CashbackCategory.catalog.filter {
            $0.superRate != nil && (!$0.premium || entitlements.allCashbackCategories)
        }
    }

    /// Super-eligible categories ordered: the user's active categories first, then by uplift desc,
    /// so the most relevant choices surface at the top. Never empty for a Pro+ tier.
    private var orderedCategories: [CashbackCategory] {
        let selected = Set(store.selectedCategoryIds(profileId: profileId))
        return superEligible.sorted { a, b in
            let sa = selected.contains(a.id), sb = selected.contains(b.id)
            if sa != sb { return sa }
            return (a.superRate ?? 0) > (b.superRate ?? 0)
        }
    }

    private var activeCategory: CashbackCategory? {
        store.superCashbackCategoryId(profileId: profileId).flatMap(CashbackCategory.lookup)
    }

    private var unlockedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            if let active = activeCategory { activeCard(active) } else { emptyActiveCard }

            GroupedSection("Доступные категории", footer: listFooter) {
                ForEach(orderedCategories) { superRow($0) }
            }
        }
        .animation(Motion.snappy, value: activeCategory)
    }

    private var listFooter: String {
        if store.selectedCategoryIds(profileId: profileId).isEmpty {
            return "Сначала активируйте категории: супер-кэшбек выгоднее на активных."
        }
        return "Повышенная ставка действует на одну выбранную категорию.."
    }

    /// The one primary summary on the screen: a standalone card is allowed here (DESIGN §4).
    private func activeCard(_ c: CashbackCategory) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: ListRow.glyphSpacing) {
                    GlyphCircle(systemImage: c.icon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.name).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("Супер-кэшбек активен")
                            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(CashbackCategory.pct(c.superRate ?? 0))
                        .font(BrandFont.title1).foregroundStyle(theme.textPrimary)
                        .monospacedDigit()
                    Text("вместо \(CashbackCategory.pct(c.baseRate))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text("Экономия в месяц около").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        AmountText(amount: monthlySaving(c), size: 15)
                    }
                    Text("При тратах \(MoneyFormat.fiat(assumedMonthlySpend)) в месяц в категории")
                        .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                }
                SecondaryButton(title: "Отключить") {
                    store.setSuperCashbackCategory(nil, profileId: profileId, entitlements: entitlements)
                }
            }
        }
    }

    private var emptyActiveCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Категория не выбрана").font(BrandFont.title2).foregroundStyle(theme.textPrimary)
            Text("Выберите категорию ниже, на неё начнёт начисляться повышенная ставка.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
    }

    private func superRow(_ c: CashbackCategory) -> some View {
        let isActive = store.superCashbackCategoryId(profileId: profileId) == c.id
        let isSelectedCategory = store.isSelected(c.id, profileId: profileId)

        return Button {
            store.setSuperCashbackCategory(isActive ? nil : c.id, profileId: profileId, entitlements: entitlements)
        } label: {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: c.icon)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(c.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                        if isSelectedCategory { Badge(kind: .dot, tint: theme.success) }
                    }
                    Text("\(CashbackCategory.pct(c.superRate ?? 0)) вместо \(CashbackCategory.pct(c.baseRate))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .animation(Motion.snappy, value: isActive)
    }

    private func monthlySaving(_ c: CashbackCategory) -> Double {
        let uplift = (c.superRate ?? c.baseRate) - c.baseRate
        return assumedMonthlySpend * uplift / 100
    }
}

#Preview {
    NavigationStack {
        SuperCashbackView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
}
