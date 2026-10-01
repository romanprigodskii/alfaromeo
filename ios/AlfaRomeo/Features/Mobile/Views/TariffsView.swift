import SwiftUI

/// Тарифы Ромео Mobile (§7.2, §9.7). The tariff is bound to the membership tier (§7.1): Base→S,
/// Pro→M (+роуминг), Infinite→безлимит. Selecting a tariff applies the matching tier instantly
/// (§4.3 mock activation) via ``AppSession/setTier(_:for:)`` — so the hub, cards, and every other
/// tier-gated surface update together (single source of truth). Higher tariffs read as a soft upgrade.
struct TariffsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var store = MobileStore.shared
    @State private var justApplied: Tier?

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: store.baseTier) }
    private var track: [Tier] { Tier.track(forBusiness: session.isBusinessMode) }
    private var catalog: [MobileTariff] { track.map(MobileTariff.make(for:)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header

                ForEach(catalog) { tariff in
                    TariffOptionCard(
                        tariff: tariff,
                        isCurrent: tariff.requiredTier == effectiveTier,
                        isLocked: tariff.requiredTier.rank > effectiveTier.rank
                    ) { apply(tariff) }
                }

                Text("Смена тарифа меняет ваш класс Ромео. Вместе с ним меняются кэшбек, лимиты, AI и связь.")
                    .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Тарифы")
        .navigationBarTitleDisplayMode(.inline)
        .animation(reduceMotion ? nil : Motion.snappy, value: effectiveTier)
        .task { await store.load(api: api, profileId: profileId) }
        .overlay(alignment: .bottom) {
            if let applied = justApplied { appliedToast(applied) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Текущий: \(MobileTariff.make(for: effectiveTier).name)")
                .font(BrandFont.title2).foregroundStyle(theme.textPrimary)
            Text("Класс \(effectiveTier.displayName). Тариф меняется вместе с классом.")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func apply(_ tariff: MobileTariff) {
        guard tariff.requiredTier != effectiveTier else { return }
        session.setTier(tariff.requiredTier, for: profileId)
        // Reflect the new tier's roaming default in the store (Infinite → роуминг включён, §7.1).
        if MobileTariff.make(for: tariff.requiredTier).isUnlimited { store.setRoaming(true) }
        withAnimation(reduceMotion ? nil : Motion.smooth) { justApplied = tariff.requiredTier }
    }

    private func appliedToast(_ tier: Tier) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                .foregroundStyle(theme.success)
            Text("Подключён тариф \(MobileTariff.make(for: tier).name)")
                .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
            Spacer(minLength: Spacing.sm)
            Button("Готово") { dismiss() }
                .font(BrandFont.headline).foregroundStyle(theme.accent)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 56)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.md)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Preview

private struct TariffsPreviewHost: View {
    let session: AppSession
    var body: some View {
        NavigationStack {
            TariffsView()
        }
        .themeProvider(profileType: session.activeProfile?.type)
        .environment(session)
        .environment(\.apiClient, MockAPIClient())
    }
}

#Preview("Тарифы") {
    TariffsPreviewHost(session: .mockAuthenticated())
}
