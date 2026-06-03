import SwiftUI

/// «Супер-кэшбек» (§9.3 / §4) — an elevated cashback rate on one chosen category. A Pro+ feature: on
/// Base the screen shows a soft ``UpsellCard`` instead of the picker (§4 — мягко, без тёмных
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
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Супер-кэшбек")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Locked (Base) — soft upsell, never blocked

    private var lockedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Супер-кэшбек").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("Повышенная ставка на одну категорию — доступно на Pro и выше.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
            UpsellCard(
                title: "Откройте супер-кэшбек",
                message: "На Pro получайте до 8% на выбранную категорию вместо обычной ставки. На Infinite — до 10%.",
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

    /// Super-eligible categories ordered: the user's active categories first, then by uplift desc —
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Супер-кэшбек").font(BrandFont.title).foregroundStyle(theme.textPrimary)
                Text("Повышенная ставка на одну выбранную категорию.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }

            if let active = activeCategory { activeCard(active) } else { emptyActiveCard }

            if store.selectedCategoryIds(profileId: profileId).isEmpty {
                Text("Сначала активируйте категории — супер-кэшбек выгоднее на ваших активных.")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Доступные категории").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                ForEach(orderedCategories) { superRow($0) }
            }
        }
        .animation(Motion.snappy, value: activeCategory)
    }

    private func activeCard(_ c: CashbackCategory) -> some View {
        SurfaceCard(elevated: true) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent)
                    Text("Активна: \(c.name)").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }
                HStack(spacing: Spacing.sm) {
                    Text(CashbackCategory.pct(c.baseRate))
                        .font(BrandFont.bodyM).foregroundStyle(theme.textSecondary).strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textSecondary)
                    Text(CashbackCategory.pct(c.superRate ?? 0))
                        .font(BrandFont.headline.weight(.semibold)).foregroundStyle(theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text("Экономия в месяц ~").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        AmountText(amount: monthlySaving(c), size: 15)
                    }
                    Text("при тратах ~40 000 ₽/мес в категории")
                        .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
                PrimaryButton(title: "Отключить") {
                    store.setSuperCashbackCategory(nil, profileId: profileId, entitlements: entitlements)
                }
            }
        }
    }

    private var emptyActiveCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Супер-кэшбек не выбран").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Text("Выберите категорию ниже — на неё начнёт начисляться повышенная ставка.")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func superRow(_ c: CashbackCategory) -> some View {
        let isActive = store.superCashbackCategoryId(profileId: profileId) == c.id
        let isSelectedCategory = store.isSelected(c.id, profileId: profileId)

        SurfaceCard(padding: Spacing.md, elevated: isActive) {
            HStack(spacing: Spacing.md) {
                Image(systemName: c.icon)
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(c.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        if isSelectedCategory { Badge(kind: .dot, tint: theme.success) }
                    }
                    HStack(spacing: Spacing.xs) {
                        Text(CashbackCategory.pct(c.baseRate))
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary).strikethrough()
                        Text("→ \(CashbackCategory.pct(c.superRate ?? 0))")
                            .font(BrandFont.caption.weight(.semibold)).foregroundStyle(theme.accent)
                    }
                }

                Spacer(minLength: Spacing.sm)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.accent)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.setSuperCashbackCategory(isActive ? nil : c.id, profileId: profileId, entitlements: entitlements)
        }
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
