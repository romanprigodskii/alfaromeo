import SwiftUI

/// Offer carousels (§9.1): glossy cards across Тревел / Страхование / Инвестиции / Игры (§13.1).
/// Tapping an offer opens the product showcase stub (``HomeRoute.openProduct``).
struct OffersCarousel: View {
    var onTapOffer: () -> Void

    var body: some View {
        DashboardSection(title: "Спецпредложения") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(HomeOffer.catalog) { offer in
                        OfferTile(offer: offer, action: onTapOffer)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollClipDisabled()
        }
    }
}
