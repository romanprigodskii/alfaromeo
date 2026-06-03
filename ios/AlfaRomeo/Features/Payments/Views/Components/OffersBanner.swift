import SwiftUI

/// Horizontally-scrolling offers banner for the payments hub (§9.2 «баннер офферов, как реф-скрин»).
/// Crypto/AI offers use the cold gradient (§13.1); the rest sit on a themed surface.
struct OffersBanner: View {
    let offers: [PaymentOffer]
    var onTap: (PaymentOffer) -> Void = { _ in }

    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.md) {
                ForEach(offers) { offer in
                    card(offer)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .scrollClipDisabled()
    }

    private func card(_ offer: PaymentOffer) -> some View {
        Button { onTap(offer) } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: offer.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(foreground(offer))
                    Spacer()
                    if let badge = offer.badge {
                        Text(badge)
                            .font(BrandFont.micro.weight(.bold))
                            .foregroundStyle(foreground(offer))
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(foreground(offer).opacity(0.18), in: Capsule())
                    }
                }
                Spacer(minLength: Spacing.sm)
                Text(offer.title)
                    .font(BrandFont.headline)
                    .foregroundStyle(foreground(offer))
                    .lineLimit(2)
                Text(offer.subtitle)
                    .font(BrandFont.caption)
                    .foregroundStyle(offer.gradient ? foreground(offer).opacity(0.85) : theme.textSecondary)
                    .lineLimit(2)
            }
            .padding(Spacing.md)
            .frame(width: 230, height: 132, alignment: .leading)
            .background(background(offer))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(offer.gradient ? Color.clear : theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(offer.title). \(offer.subtitle)")
    }

    @ViewBuilder private func background(_ offer: PaymentOffer) -> some View {
        if offer.gradient { theme.cryptoGradient } else { theme.surface }
    }

    private func foreground(_ offer: PaymentOffer) -> Color {
        offer.gradient ? BrandColors.white : theme.textPrimary
    }
}

#Preview {
    OffersBanner(offers: PaymentsMockData.offers)
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
}
