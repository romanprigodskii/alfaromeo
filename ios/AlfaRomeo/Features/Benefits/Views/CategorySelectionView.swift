import SwiftUI

/// «Выбор категорий» (§9.3) — pick which cashback categories are active. The number of slots grows
/// with the tier (Base 1 · Pro 3 · Infinite — все, §4); selection persists in ``BenefitsStore``. A
/// slot-meter adds light geymification; Base also gets a soft upsell (§4 — без тёмных паттернов).
///
/// Pushed onto the Выгода section's `NavigationStack` via `NavigationLink` from ``BenefitsView``.
struct CategorySelectionView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var baseTier: Tier = .base
    private let store = BenefitsStore.shared

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: baseTier) }
    private var entitlements: Entitlements { Entitlements.make(for: effectiveTier) }

    private var selectedCount: Int { store.selectedCount(profileId: profileId) }
    private var maxSlots: Int { min(store.categoryLimit(for: entitlements), CashbackCategory.catalog.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                intro
                if entitlements.allCashbackCategories {
                    unlimitedNote
                } else {
                    slotMeter
                }
                categoryList
                if entitlements.cashback == .basic {
                    UpsellCard(
                        title: "Больше категорий",
                        message: "На Pro выбирайте до 3 категорий, на Infinite — все сразу.",
                        recommendedTier: .pro
                    )
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.snappy, value: selectedCount)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Категории")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Выберите категории").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text("Кэшбек начисляется только по активным категориям.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: Slot meter (geymification)

    private var slotMeter: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Слоты категорий").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Badge(kind: .text(effectiveTier.shortLabel), tint: theme.accent)
                }
                Text("\(selectedCount) из \(maxSlots)")
                    .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                ProgressBar(value: Double(selectedCount) / Double(max(maxSlots, 1)), tint: theme.accent)
                Text(slotHint).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var slotHint: String {
        let free = maxSlots - selectedCount
        if free <= 0 { return "Все слоты активны" }
        return free == 1 ? "Ещё 1 слот доступен!" : "Ещё \(free) слота доступно!"
    }

    private var unlimitedNote: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "infinity").font(.system(size: 14, weight: .bold)).foregroundStyle(theme.success)
            Text("Все категории активны без лимита").font(BrandFont.callout).foregroundStyle(theme.success)
        }
    }

    // MARK: Category list

    private var categoryList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(CashbackCategory.catalog) { categorySlot($0) }
        }
    }

    @ViewBuilder
    private func categorySlot(_ cat: CashbackCategory) -> some View {
        let selected = store.isSelected(cat.id, profileId: profileId)
        let locked = cat.premium && !entitlements.allCashbackCategories

        SurfaceCard(padding: Spacing.md, elevated: selected) {
            HStack(spacing: Spacing.md) {
                Image(systemName: cat.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? theme.accent : theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(selected ? theme.accent.opacity(0.12) : theme.elevated,
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(cat.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        if cat.premium { Badge(kind: .text("Infinite"), tint: theme.accent) }
                    }
                    Text("Кэшбек \(CashbackCategory.pct(cat.baseRate))")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }

                Spacer(minLength: Spacing.sm)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textSecondary)
                } else {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selected ? theme.accent : theme.border)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1)
        )
        .opacity(locked ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !locked else { return }
            store.toggleCategory(cat.id, profileId: profileId, entitlements: entitlements)
        }
        .animation(Motion.snappy, value: selected)
    }
}

#Preview {
    NavigationStack {
        CategorySelectionView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
}
