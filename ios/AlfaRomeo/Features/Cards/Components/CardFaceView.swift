import SwiftUI

/// The big card visual (§6.3 "крупная карта · дизайн по типу/тиру"). Self-contained and
/// brand-fixed: it draws from ``CardDesign`` (artwork palette), not the app `theme`, because a card's
/// identity doesn't re-theme with the active profile. Scales to any width (carousel, detail, picker
/// thumbnail) and overlays state — frozen / в доставке / истёкла / сожжена.
struct CardFaceView: View {
    let card: CardItem

    /// Reference width the type scale is tuned for; everything scales relative to the real width.
    private let referenceWidth: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            let scale = max(geo.size.width / referenceWidth, 0.3)
            face(scale: scale)
        }
        .aspectRatio(1.586, contentMode: .fit) // ISO/IEC 7810 ID-1
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.typeLabel), оканчивается на \(card.last4), \(card.stateLabel)")
    }

    private var design: CardDesign { card.design }

    @ViewBuilder
    private func face(scale s: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20 * s, style: .continuous)
        ZStack {
            // Base gradient + sheen
            shape.fill(LinearGradient(colors: design.gradient,
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(gloss(scale: s))
            if design.usesCryptoSheen {
                shape.fill(LinearGradient(colors: [BrandColors.cryptoBlue.opacity(0.35),
                                                   BrandColors.cryptoCyan.opacity(0.18), .clear],
                                          startPoint: .bottomLeading, endPoint: .topTrailing))
            }

            // Watermark monogram
            Text(design.monogram)
                .font(.system(size: 150 * s, weight: .black, design: .rounded))
                .foregroundStyle(design.textColor.opacity(design.isMetal ? 0.16 : 0.10))
                .offset(x: 90 * s, y: 28 * s)
                .clipped()

            content(scale: s)
                .padding(18 * s)
                .foregroundStyle(design.textColor)
        }
        .overlay(
            shape.strokeBorder(design.accent.opacity(0.55), lineWidth: 1 * s)
        )
        .overlay { stateOverlay(scale: s, shape: shape) }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.35), radius: 14 * s, x: 0, y: 8 * s)
    }

    // MARK: Foreground content

    @ViewBuilder
    private func content(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text("АЛЬФА · РОМЕО")
                        .font(.system(size: 12 * s, weight: .bold))
                        .tracking(1.5 * s)
                        .opacity(0.9)
                    Text(card.typeLabel.uppercased())
                        .font(.system(size: 9 * s, weight: .semibold))
                        .tracking(1 * s)
                        .opacity(0.6)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6 * s) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 17 * s, weight: .semibold))
                        .opacity(0.85)
                    if card.isDefault {
                        Text("ОСНОВНАЯ")
                            .font(.system(size: 8 * s, weight: .bold))
                            .tracking(0.8 * s)
                            .padding(.horizontal, 6 * s).padding(.vertical, 2 * s)
                            .background(design.accent.opacity(0.9), in: Capsule())
                            .foregroundStyle(design.accent.bestOnColor)
                    }
                }
            }

            Spacer(minLength: 0)

            // Chip + crypto asset
            HStack(spacing: 8 * s) {
                chip(scale: s)
                if card.type == .crypto, let asset = card.assetLink {
                    HStack(spacing: 3 * s) {
                        Image(systemName: "bitcoinsign.circle.fill").font(.system(size: 11 * s))
                        Text(asset).font(.system(size: 11 * s, weight: .bold))
                    }
                    .padding(.horizontal, 7 * s).padding(.vertical, 3 * s)
                    .background(design.textColor.opacity(0.16), in: Capsule())
                }
                if card.isBurner {
                    Text("ОДНОРАЗОВАЯ").font(.system(size: 9 * s, weight: .bold)).tracking(0.6 * s)
                        .padding(.horizontal, 7 * s).padding(.vertical, 3 * s)
                        .background(design.accent.opacity(0.22), in: Capsule())
                }
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                Text("•• \(card.last4)")
                    .font(.system(size: 21 * s, weight: .semibold, design: .monospaced))
                Spacer(minLength: 0)
                paymentBadge(scale: s)
            }
        }
    }

    /// The EMV-style chip rectangle.
    private func chip(scale s: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0xD9C173), Color(hex: 0xA98C3E)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 34 * s, height: 26 * s)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s)
                    .strokeBorder(.black.opacity(0.18), lineWidth: 0.5 * s)
            )
            .overlay(
                Rectangle().fill(.black.opacity(0.18)).frame(height: 0.6 * s)
            )
    }

    /// «МИР» payment-system mark (no SF Symbol exists).
    private func paymentBadge(scale s: CGFloat) -> some View {
        Text("МИР")
            .font(.system(size: 13 * s, weight: .heavy, design: .rounded))
            .tracking(0.5 * s)
            .padding(.horizontal, 7 * s).padding(.vertical, 3 * s)
            .background(design.textColor.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 5 * s, style: .continuous))
    }

    private func gloss(scale s: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: design.isMetal
                ? [.white.opacity(0.22), .clear, .white.opacity(0.06), .clear]
                : [.white.opacity(0.12), .clear, .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: State overlay

    @ViewBuilder
    private func stateOverlay(scale s: CGFloat, shape: RoundedRectangle) -> some View {
        switch card.state {
        case .frozen:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(BrandColors.cryptoBlue.opacity(0.10))
                overlayBadge("snowflake", "Заморожена", tint: BrandColors.cryptoCyan, scale: s)
            }
        case .shipping, .issuing:
            ZStack {
                shape.fill(.black.opacity(0.55))
                overlayBadge("shippingbox.fill", "В доставке", tint: .white, scale: s)
            }
        case .expired:
            ZStack {
                shape.fill(.black.opacity(0.55))
                overlayBadge("calendar.badge.exclamationmark", "Истекла", tint: .white, scale: s)
            }
            .saturation(0)
        case .burned:
            ZStack {
                shape.fill(.black.opacity(0.6))
                overlayBadge("flame.fill", "Сожжена", tint: BrandColors.warningDark, scale: s)
            }
        case .active:
            EmptyView()
        }
    }

    private func overlayBadge(_ icon: String, _ text: String, tint: Color, scale s: CGFloat) -> some View {
        VStack(spacing: 6 * s) {
            Image(systemName: icon).font(.system(size: 26 * s, weight: .semibold))
            Text(text).font(.system(size: 14 * s, weight: .bold))
        }
        .foregroundStyle(tint)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            CardFaceView(card: CardItem(id: "p", accountId: "a", type: .virtual, last4: "4921",
                                        state: .active, designId: "pro", isDefault: true))
            CardFaceView(card: CardItem(id: "i", accountId: "a", type: .plastic, last4: "1180",
                                        state: .active, designId: "infinite", isDefault: false))
            CardFaceView(card: CardItem(id: "c", accountId: "a", type: .crypto, last4: "7788",
                                        state: .active, designId: "crypto", isDefault: false, assetLink: "BTC"))
            CardFaceView(card: CardItem(id: "f", accountId: "a", type: .virtual, last4: "0001",
                                        state: .frozen, designId: "base", isDefault: false))
            CardFaceView(card: CardItem(id: "b", accountId: "a", type: .disposable, last4: "9999",
                                        state: .active, designId: "burner", isDefault: false))
        }
        .padding(24)
    }
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
