import SwiftUI

/// Cards block (§9.1): a horizontal carousel of the profile's cards + an «Заказать карту» tile.
/// Tapping a card opens its detail (cross-module ``CardsRoute.detail``, §6.3); the «Все» header action
/// opens the cards list (delivery tracking lives there, not as a dashboard banner).
struct CardsCarousel: View {
    let cards: [Card]
    var onTapCard: (Card) -> Void
    var onOrder: () -> Void
    var onSeeAll: () -> Void

    var body: some View {
        DashboardSection(
            title: "Карты",
            actionTitle: cards.isEmpty ? nil : "Все",
            action: cards.isEmpty ? nil : onSeeAll
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(cards) { card in
                        Button { onTapCard(card) } label: { BankCardView(card: card) }
                            .buttonStyle(PressableButtonStyle())
                    }
                    OrderCardTile(action: onOrder)
                }
                .padding(.vertical, Spacing.xs)
            }
            .scrollClipDisabled()
        }
    }
}

/// «Заказать карту» dashed tile that closes the carousel (§6.2).
private struct OrderCardTile: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "plus").font(.system(size: 22, weight: .bold)).foregroundStyle(theme.accent)
                Text("Заказать\nкарту")
                    .font(BrandFont.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)
            }
            .frame(width: 132, height: 296 * 0.62)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(theme.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Заказать карту")
    }
}
