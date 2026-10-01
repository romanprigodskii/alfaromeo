import SwiftUI

/// Flat bank card art (docs/DESIGN.md §5): a solid face (red for personal, graphite for business),
/// at most a 4% vertical shade, radius 14, aspect 1.586. Content: bank wordmark, an optional label,
/// last four digits in mono, the network mark. No chip, no NFC waves, no gloss, no glow shadow.
///
/// ```swift
/// CardArt(last4: "4921")                                   // fills the proposed width
/// CardArt(last4: "4921", label: "Виртуальная", style: .graphite, width: 296)
/// CardArt(card: card)                                       // style from designId / type
/// ```
struct CardArt: View {
    enum Style: Sendable {
        /// Heritage red: personal cards.
        case red
        /// Graphite: business cards.
        case graphite
        /// Near-black: premium and crypto cards.
        case ink
        /// Child profile.
        case violet
        /// Joint / family profile.
        case teal

        var face: Color {
            switch self {
            case .red:      return BrandColors.heritageRedLight
            case .graphite: return Color(hex: 0x2E333B)
            case .ink:      return Color(hex: 0x1A1818)
            case .violet:   return BrandColors.childVioletLight
            case .teal:     return BrandColors.jointTealLight
            }
        }
    }

    var last4: String
    var label: String? = nil
    var style: Style = .red
    var network: String = "МИР"
    /// Fixed width; `nil` fills the proposed width.
    var width: CGFloat? = nil
    var isFrozen: Bool = false

    static let aspectRatio: CGFloat = 1.586
    static let cornerRadius: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardArt.cornerRadius, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape.fill(style.face)
            // ≤4% vertical shade: reads as a physical object without gloss.
            shape.fill(LinearGradient(colors: [.white.opacity(0.04), .black.opacity(0.04)],
                                      startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Альфа-Ромео").font(BrandFont.body(13, weight: .semibold))
                    Spacer(minLength: Spacing.sm)
                    if isFrozen {
                        Label("Заморожена", systemImage: "snowflake")
                            .font(BrandFont.micro)
                    } else if let label {
                        Text(label).font(BrandFont.micro).opacity(0.8)
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .lastTextBaseline) {
                    Text("•• \(last4)").font(BrandFont.code(17, weight: .medium))
                    Spacer(minLength: Spacing.sm)
                    Text(network).font(BrandFont.body(15, weight: .bold)).italic()
                }
            }
            .foregroundStyle(.white)
            .padding(Spacing.md)
        }
        .saturation(isFrozen ? 0.15 : 1)
        .aspectRatio(CardArt.aspectRatio, contentMode: .fit)
        .frame(width: width)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Карта, оканчивается на \(last4)\(isFrozen ? ", заморожена" : "")")
    }
}

extension CardArt {
    /// Card art for a contract ``Card``: style from its design (business → graphite, child → violet,
    /// premium / crypto → ink, otherwise red) and a type label.
    init(card: Card, width: CGFloat? = nil) {
        let style: Style
        switch (card.designId, card.type) {
        case ("biz", _):                   style = .graphite
        case ("child", _):                 style = .violet
        case ("joint", _):                 style = .teal
        case ("infinite", _), (_, .crypto): style = .ink
        default:                           style = .red
        }
        let label: String
        switch card.type {
        case .virtual:    label = "Виртуальная"
        case .plastic:    label = "Пластиковая"
        case .crypto:     label = "Крипто"
        case .disposable: label = "Одноразовая"
        }
        self.init(last4: card.last4, label: label, style: style, width: width,
                  isFrozen: card.state == .frozen)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        CardArt(last4: "4921", label: "Виртуальная")
        HStack(spacing: Spacing.md) {
            CardArt(last4: "0042", style: .graphite, width: 160)
            CardArt(last4: "7710", style: .ink, width: 160, isFrozen: true)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
