import SwiftUI

/// «Предложения / партнёры» (§9.3) — a catalog of partner cashback offers (mock list with logos +
/// percentages). Filterable by category. Premium offers (§4.1 «премиум-партнёры») are exclusive to
/// Infinite: shown in an elevated section there, and a restrained teaser otherwise — never a hard wall.
struct PartnerOffersView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme

    @State private var baseTier: Tier = .base
    @State private var filter: String? = nil   // nil = «Все»

    private var profileId: String { session.activeProfile?.id ?? "" }
    private var effectiveTier: Tier { session.currentTier(for: profileId, fallback: baseTier) }
    private var entitlements: Entitlements { Entitlements.make(for: effectiveTier) }

    /// Regular (non-premium) offers matching the active filter. Premium offers render only in their
    /// own section below, so they are excluded here.
    private var shown: [PartnerOffer] {
        PartnerOffer.offers.filter { offer in
            !offer.premium && (filter == nil || offer.categoryId == filter)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                intro
                filterPills
                offerList
                if filter == nil { premiumSection }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Партнёры")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Партнёры").font(BrandFont.title).foregroundStyle(theme.textPrimary)
            Text("Дополнительный кэшбек у избранных брендов.")
                .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: Filter pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterPill(title: "Все", id: nil)
                ForEach(PartnerOffer.filterCategoryIds, id: \.self) { cid in
                    filterPill(title: CashbackCategory.lookup(cid)?.name ?? cid, id: cid)
                }
            }
        }
    }

    private func filterPill(title: String, id: String?) -> some View {
        let active = filter == id
        return Text(title)
            .font(BrandFont.caption.weight(.medium))
            .foregroundStyle(active ? theme.onAccent : theme.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 32)
            .background(active ? theme.accent : theme.surface, in: Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : theme.border, lineWidth: 1))
            .contentShape(Capsule())
            .onTapGesture { withAnimation(Motion.snappy) { filter = id } }
    }

    // MARK: Offer list

    @ViewBuilder
    private var offerList: some View {
        if shown.isEmpty {
            SurfaceCard {
                Text("Нет предложений в этой категории")
                    .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: Spacing.sm) {
                ForEach(shown) { offerCard($0, elevated: false) }
            }
        }
    }

    private func offerCard(_ o: PartnerOffer, elevated: Bool) -> some View {
        SurfaceCard(padding: Spacing.md, elevated: elevated) {
            HStack(spacing: Spacing.md) {
                Image(systemName: o.logo)
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 48, height: 48)
                    .background(theme.accent.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(o.brand).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                        if o.premium { Badge(kind: .text("Infinite"), tint: theme.accent) }
                    }
                    Text(o.blurb).font(BrandFont.caption).foregroundStyle(theme.textSecondary).lineLimit(2)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(CashbackCategory.pct(o.cashbackPct))
                        .font(BrandFont.headline).foregroundStyle(theme.success)
                    Text("кэшбек").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    // MARK: Premium (Infinite-exclusive) section

    @ViewBuilder
    private var premiumSection: some View {
        if entitlements.allCashbackCategories {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.accent)
                    Text("Эксклюзивные партнёры для Infinite")
                        .font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                }
                ForEach(PartnerOffer.premiumOffers) { offerCard($0, elevated: true) }
            }
        } else {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.accent)
                Text("Эксклюзивные партнёры открываются на Infinite")
                    .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.xs)
        }
    }
}

#Preview {
    NavigationStack {
        PartnerOffersView()
    }
    .environment(AppSession.mockAuthenticated())
    .environment(\.apiClient, MockAPIClient())
    .environment(\.theme, .default)
}
