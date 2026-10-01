import SwiftUI

/// The big card visual (§6.3, docs/DESIGN.md §5 card art). Flat face from ``CardDesign`` with a ≤4%
/// vertical shade, bank wordmark, type label, last 4 in monospace and the network mark. No chip, no
/// NFC waves, no gloss, no shadow. Brand-fixed: it draws from ``CardDesign``, not the app `theme`,
/// because a card's identity doesn't re-theme with the active profile. Scales to any width (carousel,
/// detail, picker thumbnail) and marks non-active states (заморожена / в доставке / истекла / сожжена).
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
        let shape = RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
        ZStack {
            shape.fill(design.face)
            // ≤4% vertical shade: reads as a physical object without gloss.
            shape.fill(LinearGradient(colors: [.white.opacity(0.04), .black.opacity(0.04)],
                                      startPoint: .top, endPoint: .bottom))
            if dims { shape.fill(.black.opacity(0.28)) }

            content(scale: s)
                .padding(16 * s)
                .foregroundStyle(design.textColor)
        }
        .saturation(saturation)
        .clipShape(shape)
    }

    // MARK: Content

    @ViewBuilder
    private func content(scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Альфа-Ромео")
                    .font(BrandFont.body(13 * s, weight: .semibold))
                Spacer(minLength: 8 * s)
                if let state = stateMark {
                    Label(state.text, systemImage: state.icon)
                        .font(BrandFont.body(12 * s, weight: .medium))
                } else {
                    Text(topLabel)
                        .font(BrandFont.body(12 * s, weight: .medium))
                        .opacity(0.8)
                }
            }

            Spacer(minLength: 0)

            if card.type == .crypto, let asset = card.assetLink {
                Text(asset)
                    .font(BrandFont.body(13 * s, weight: .medium))
                    .opacity(0.8)
                    .padding(.bottom, 4 * s)
            }

            HStack(alignment: .lastTextBaseline) {
                Text("•• \(card.last4)")
                    .font(BrandFont.code(17 * s, weight: .medium))
                Spacer(minLength: 8 * s)
                Text("МИР")
                    .font(BrandFont.body(15 * s, weight: .bold))
                    .italic()
            }
        }
        .lineLimit(1)
    }

    /// Type label, with «основная» for the default card.
    private var topLabel: String {
        card.isDefault ? "\(card.typeLabel), основная" : card.typeLabel
    }

    // MARK: State

    private var stateMark: (icon: String, text: String)? {
        switch card.state {
        case .frozen:             return ("snowflake", "Заморожена")
        case .shipping, .issuing: return ("shippingbox", "В доставке")
        case .expired:            return ("calendar", "Истекла")
        case .burned:             return ("flame", "Сожжена")
        case .active:             return nil
        }
    }

    /// Frozen keeps a hint of colour (like ``CardArt``); spent / expired cards go fully grey.
    private var saturation: Double {
        switch card.state {
        case .active, .shipping, .issuing: return 1
        case .frozen:                      return 0.15
        case .expired, .burned:            return 0
        }
    }

    private var dims: Bool {
        switch card.state {
        case .shipping, .issuing, .expired, .burned: return true
        case .active, .frozen:                       return false
        }
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
        .padding(16)
    }
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
