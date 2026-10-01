import SwiftUI

/// Cards block (§9.1): a horizontal shelf of flat card art (``CardArt``) plus an «Заказать карту»
/// tile. Tapping a card opens its detail (cross-module ``CardsRoute.detail``, §6.3); the «Все» header
/// action opens the cards list (delivery tracking lives there, not as a dashboard banner).
struct CardsCarousel: View {
    let cards: [Card]
    var onTapCard: (Card) -> Void
    var onOrder: () -> Void
    var onSeeAll: () -> Void

    static let cardWidth: CGFloat = 260

    var body: some View {
        DashboardSection(
            title: "Карты",
            actionTitle: cards.isEmpty ? nil : "Все",
            action: cards.isEmpty ? nil : onSeeAll
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm + 4) {
                    ForEach(cards) { card in
                        Button { onTapCard(card) } label: { art(card) }
                            .buttonStyle(PressableButtonStyle())
                    }
                    OrderCardTile(action: onOrder)
                }
            }
            .scrollClipDisabled()
        }
    }

    /// Flat art from the card's design; the default card is labelled «Основная» instead of its type.
    private func art(_ card: Card) -> CardArt {
        var art = CardArt(card: card, width: Self.cardWidth)
        if card.isDefault { art.label = "Основная" }
        return art
    }
}

/// «Заказать карту» tile that closes the shelf (§6.2): a neutral `fill` face the size of a card.
private struct OrderCardTile: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(theme.textPrimary)
                Text("Заказать\nкарту")
                    .font(BrandFont.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
            }
            .frame(width: 120, height: CardsCarousel.cardWidth / CardArt.aspectRatio)
            .background(theme.fill, in: RoundedRectangle(cornerRadius: CardArt.cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Заказать карту")
    }
}
