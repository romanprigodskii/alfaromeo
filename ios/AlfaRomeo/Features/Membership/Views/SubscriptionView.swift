import SwiftUI

/// «Подписка / Тариф» (§4.3, §9.3): compare the tiers for the active profile's track and
/// upgrade/downgrade. Activation is a live mock — entitlements update immediately.
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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Тир — глобальная ось привилегий: кэшбек, лимиты крипты, AI, мобильный пакет, поддержка.")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)

                liveEntitlements

                ForEach(tiers, id: \.self) { tier in
                    TierCard(
                        entitlements: Entitlements.make(for: tier),
                        isCurrent: tier == effectiveTier,
                        onSelect: { session.setTier(tier, for: profileId) }
                    )
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Подписка")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.snappy, value: effectiveTier)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    /// Live snapshot of the active entitlements — updates the instant a tier is selected.
    private var liveEntitlements: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Активный тариф").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    Spacer()
                    Badge(kind: .text(effectiveTier.shortLabel), tint: theme.accent)
                }
                Text(effectiveTier.displayName).font(BrandFont.title).foregroundStyle(theme.textPrimary)
                HStack(spacing: Spacing.xl) {
                    chip("Карты", entitlements.maxCardsLabel)
                    chip("AI", entitlements.aiLimitLabel)
                    chip("Спред", entitlements.cryptoSpread.label.replacingOccurrences(of: " спред", with: ""))
                }
            }
        }
    }

    private func chip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(BrandFont.headline).foregroundStyle(theme.textPrimary).lineLimit(1)
            Text(label).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
        }
    }
}
