import SwiftUI

/// «Партнёры» (§9.3): a catalog of partner cashback offers (mock list with logos +
/// percentages). Filterable by category. Premium offers (§4.1 «премиум-партнёры») are exclusive to
/// Infinite: shown in an elevated section there, and a restrained teaser otherwise, never a hard wall.
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
            VStack(alignment: .leading, spacing: Spacing.section) {
                filterPills
                offerList
                if filter == nil { premiumSection }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Партнёры")
        .navigationBarTitleDisplayMode(.inline)
        .task { baseTier = (try? await api.subscription(profileId: profileId))?.tier ?? .base }
    }

    // MARK: Filter chips

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                filterPill(title: "Все", id: nil)
                ForEach(PartnerOffer.filterCategoryIds, id: \.self) { cid in
                    filterPill(title: CashbackCategory.lookup(cid)?.name ?? cid, id: cid)
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
        .padding(.horizontal, -Spacing.screen)
    }

    private func filterPill(title: String, id: String?) -> some View {
        let active = filter == id
        return Text(title)
            .font(BrandFont.subheadline)
            .foregroundStyle(active ? theme.onAccent : theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(active ? theme.accent : theme.fill,
                        in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(Motion.snappy) { filter = id } }
    }

    // MARK: Offer list

    @ViewBuilder
    private var offerList: some View {
        if shown.isEmpty {
            Text("Нет предложений в этой категории")
                .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            GroupedSection(footer: "Дополнительный кэшбек у партнёров банка.") {
                ForEach(shown) { offerRow($0) }
            }
        }
    }

    private func offerRow(_ o: PartnerOffer) -> some View {
        HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: o.logo)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(o.brand).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    if o.premium { Badge(kind: .text("Infinite")) }
                }
                Text(o.blurb).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary).lineLimit(2)
            }

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(CashbackCategory.pct(o.cashbackPct))
                    .font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                Text("кэшбек").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
        .accessibilityElement(children: .combine)
    }

    // MARK: Premium (Infinite-exclusive) section

    @ViewBuilder
    private var premiumSection: some View {
        if entitlements.allCashbackCategories {
            GroupedSection("Партнёры Infinite") {
                ForEach(PartnerOffer.premiumOffers) { offerRow($0) }
            }
        } else {
            Text("Эксклюзивные партнёры открываются на Infinite")
                .font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Spacing.md)
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
