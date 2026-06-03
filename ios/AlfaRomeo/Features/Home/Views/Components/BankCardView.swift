import SwiftUI

/// A glossy bank-card face for the dashboard carousel (§9.1, §13.2). The gradient comes from the
/// card's design/type — brand artwork, intentionally **not** theme-semantic — with a gloss highlight,
/// chip, NFC glyph, masked number and a МИР mark.
struct BankCardView: View {
    let card: Card
    var width: CGFloat = 296

    private var height: CGFloat { width * 0.62 }

    /// Brand artwork per design/tier (§13.2). Crypto cards take the cold gradient (§13.1).
    private var stops: [Color] {
        if card.type == .crypto { return [Color(hex: 0x4F7CFF), Color(hex: 0x19D3E0)] }
        switch card.designId {
        case "biz":      return [Color(hex: 0x3A4453), Color(hex: 0x0F141C)]
        case "child":    return [Color(hex: 0x8C6BFF), Color(hex: 0x4A2FB0)]
        case "infinite": return [Color(hex: 0x2B2D34), Color(hex: 0x0A0A0B)]
        default:         return [Color(hex: 0xE2120F), Color(hex: 0x5E0907)]   // pro / heritage red
        }
    }

    private var typeLabel: String {
        switch card.type {
        case .virtual:    return "Виртуальная"
        case .plastic:    return "Пластиковая"
        case .crypto:     return "Крипто"
        case .disposable: return "Одноразовая"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing))

            // Gloss: a soft diagonal highlight sweeping from the top-left.
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.22), .clear],
                                     startPoint: .topLeading, endPoint: .center))
                .blendMode(.softLight)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Альфа·Ромео").font(BrandFont.body(13, weight: .semibold))
                    Spacer()
                    Text(typeLabel).font(BrandFont.mono(11, weight: .medium)).opacity(0.85)
                }

                Spacer()

                HStack(spacing: Spacing.sm) {
                    chip
                    Image(systemName: "wave.3.right").font(.system(size: 16, weight: .semibold)).opacity(0.85)
                    Spacer()
                    if card.isDefault {
                        Text("ОСНОВНАЯ")
                            .font(BrandFont.micro)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.white.opacity(0.18), in: Capsule())
                    }
                }

                Spacer()

                HStack(alignment: .lastTextBaseline) {
                    Text("·· \(card.last4)").font(BrandFont.mono(19, weight: .semibold))
                    Spacer()
                    Text("МИР").font(BrandFont.display(15, weight: .black)).italic().opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .padding(Spacing.md)
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: (stops.first ?? .black).opacity(0.35), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typeLabel) карта, оканчивается на \(card.last4)")
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0xE6C97A), Color(hex: 0xB8902F)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 34, height: 26)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.25)))
    }
}
