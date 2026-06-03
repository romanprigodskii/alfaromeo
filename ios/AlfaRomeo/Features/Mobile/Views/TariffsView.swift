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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                ForEach(catalog) { tariff in
                    TariffOptionCard(
                        tariff: tariff,
                        isCurrent: tariff.requiredTier == effectiveTier,
                        isLocked: tariff.requiredTier.rank > effectiveTier.rank
                    ) { apply(tariff) }
                }

                Text("Смена тарифа меняет ваш класс Ромео — кэшбек, лимиты, AI и связь растут вместе (§4, §7.1).")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
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
            Text("Тариф в связке с классом").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text("Текущий: \(MobileTariff.make(for: effectiveTier).name) · \(effectiveTier.displayName)")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
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
            Image(systemName: "checkmark.seal.fill").foregroundStyle(theme.onAccent)
            Text("Подключён тариф \(MobileTariff.make(for: tier).name)")
                .font(BrandFont.callout.weight(.semibold)).foregroundStyle(theme.onAccent)
            Spacer(minLength: Spacing.sm)
            Button("Готово") { dismiss() }
                .font(BrandFont.callout.weight(.bold)).foregroundStyle(theme.onAccent)
        }
        .padding(Spacing.md)
        .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(Spacing.lg)
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
