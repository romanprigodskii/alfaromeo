import SwiftUI

/// «Категории» (§9.3): pick which cashback categories are active. The number of slots grows with
/// the tier (Base 1, Pro 3, Infinite all, §4); selection persists in ``BenefitsStore``. A slot
/// meter shows usage; Base also gets a soft upsell (§4, без тёмных паттернов).
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                if entitlements.allCashbackCategories {
                    unlimitedNote
                } else {
                    slotMeter
                }
                categoryList
                if entitlements.cashback == .basic {
                    UpsellCard(
                        title: "Больше категорий",
                        message: "На Pro до 3 категорий, на Infinite все сразу.",
                        recommendedTier: .pro
                    )
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.snappy, value: selectedCount)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Категории")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Slot meter (plain summary on the background, no card)

    private var slotMeter: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Активно \(selectedCount) из \(maxSlots)")
                    .font(BrandFont.title2).foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                Badge(kind: .text(effectiveTier.shortLabel))
            }
            ProgressBar(value: Double(selectedCount) / Double(max(maxSlots, 1)), tint: theme.accent)
            Text(slotHint).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
        }
    }

    private var slotHint: String {
        let free = maxSlots - selectedCount
        if free <= 0 { return "Все слоты заняты" }
        return "Свободно слотов: \(free)"
    }

    private var unlimitedNote: some View {
        Text("Все категории активны без лимита")
            .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
    }

    // MARK: Category list

    private var categoryList: some View {
        GroupedSection(footer: "Кэшбек начисляется только по активным категориям.") {
            ForEach(CashbackCategory.catalog) { categoryRow($0) }
        }
    }

    private func categoryRow(_ cat: CashbackCategory) -> some View {
        let selected = store.isSelected(cat.id, profileId: profileId)
        let locked = cat.premium && !entitlements.allCashbackCategories

        return Button {
            guard !locked else { return }
            store.toggleCategory(cat.id, profileId: profileId, entitlements: entitlements)
        } label: {
            HStack(spacing: ListRow.glyphSpacing) {
                GlyphCircle(systemImage: cat.icon)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(cat.name).font(BrandFont.bodyM)
                            .foregroundStyle(locked ? theme.textTertiary : theme.textPrimary)
                        if cat.premium { Badge(kind: .text("Infinite")) }
                    }
                    Text("Кэшбек \(CashbackCategory.pct(cat.baseRate))")
                        .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }

                Spacer(minLength: Spacing.sm)

                if locked {
                    Image(systemName: "lock")
                        .font(.system(size: 17)).foregroundStyle(theme.textTertiary)
                } else {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? theme.accent : theme.textTertiary)
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
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
