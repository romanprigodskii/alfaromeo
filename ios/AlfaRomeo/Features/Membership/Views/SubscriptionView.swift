import SwiftUI

/// «Подписка / Тариф» (§4.3, §9.3): compare the tiers for the active profile's track and
/// upgrade/downgrade. Activation is a live mock: entitlements update immediately.
struct SubscriptionView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var baseTier: Tier = .base

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: baseTier) }
    private var entitlements: Entitlements { Entitlements.make(for: effectiveTier) }
    private var tiers: [Tier] { Tier.track(forBusiness: session.isBusinessMode) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                liveEntitlements

                ForEach(tiers, id: \.self) { tier in
                    TierCard(
                        entitlements: Entitlements.make(for: tier),
                        isCurrent: tier == effectiveTier,
                        onSelect: { session.setTier(tier, for: profileId) }
                    )
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Подписка")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.snappy, value: effectiveTier)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    /// Live snapshot of the active entitlements; updates the instant a tier is selected.
    private var liveEntitlements: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Текущий тариф").font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                Text(effectiveTier.displayName).font(BrandFont.title1).foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
            }
            HStack(alignment: .top, spacing: Spacing.xl) {
                stat("Карты", entitlements.maxCardsLabel)
                stat("AI", entitlements.aiLimitLabel)
                stat("Спред", entitlements.cryptoSpread.label.replacingOccurrences(of: " спред", with: ""))
            }
            Text("Тариф определяет кэшбек, лимиты, AI, мобильную связь и поддержку.")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                .monospacedDigit().lineLimit(1)
            Text(label).font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
        }
    }
}
