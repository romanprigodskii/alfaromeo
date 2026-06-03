import SwiftUI

/// Cards block (§9.1): a horizontal carousel of the profile's cards + an «Заказать карту» tile, plus
/// a delivery-status row when a physical card is in transit (§6.2). Tapping a card opens its detail
/// (cross-module ``CardsRoute.detail``, §6.3); the «Все» header action opens the cards list.
struct CardsCarousel: View {
    let cards: [Card]
    let pendingDelivery: CardOrder?
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

            if let pendingDelivery {
                DeliveryRow(order: pendingDelivery)
            }
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

/// Physical-card delivery status (mock logistics, §6.2).
private struct DeliveryRow: View {
    let order: CardOrder
    @Environment(\.theme) private var theme

    private var statusText: String {
        switch order.physicalStatus {
        case .ordered:   return "Оформлена"
        case .printing:  return "Печатается"
        case .shipping:  return "В пути"
        case .delivered: return "Доставлена"
        case .none:      return "—"
        }
    }

    var body: some View {
        SurfaceCard(padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Пластиковая карта")
                        .font(BrandFont.caption.weight(.medium)).foregroundStyle(theme.textPrimary)
                    if let tracking = order.tracking {
                        Text(tracking).font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    }
                }
                Spacer()
                StatusPill(status: order.physicalStatus == .shipping ? .processing : .pending,
                           text: statusText)
            }
        }
    }
}
