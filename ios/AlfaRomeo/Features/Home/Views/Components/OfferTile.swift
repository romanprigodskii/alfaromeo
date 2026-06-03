import SwiftUI

/// A single glossy offer card (§9.1, §13.1).
struct OfferTile: View {
    let offer: HomeOffer
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(LinearGradient(colors: offer.category.gradient,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.25), .clear],
                                         startPoint: .topLeading, endPoint: .center))
                    .blendMode(.softLight)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: offer.category.icon).font(.system(size: 12, weight: .bold))
                        Text(offer.category.title).font(BrandFont.micro)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm).padding(.vertical, 4)
                    .background(Color.black.opacity(0.18), in: Capsule())

                    Spacer()

                    Text(offer.title).font(BrandFont.body(16, weight: .semibold)).foregroundStyle(.white)
                    Text(offer.subtitle).font(BrandFont.caption).foregroundStyle(.white.opacity(0.85))
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 212, height: 132)
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(Color.white.opacity(0.12)))
            .shadow(color: (offer.category.gradient.first ?? .black).opacity(0.3), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(offer.category.title): \(offer.title)")
    }
}
