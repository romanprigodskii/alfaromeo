import SwiftUI

/// Offers (§9.1): Тревел / Страхование / Инвестиции / Игры as a plain grouped list, one row per offer
/// with the category glyph. Tapping an offer opens the product showcase (``HomeRoute.openProduct``).
struct OffersBlock: View {
    var onTapOffer: () -> Void

    var body: some View {
        GroupedSection("Предложения") {
            ForEach(HomeOffer.catalog) { offer in
                Button(action: onTapOffer) {
                    ListRow(icon: offer.category.icon, title: offer.title,
                            subtitle: offer.subtitle, showsChevron: true)
                }
                .buttonStyle(.row)
                .accessibilityLabel("\(offer.category.title): \(offer.title), \(offer.subtitle)")
            }
        }
    }
}
