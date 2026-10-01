import SwiftUI
import UIKit

/// A monochrome glyph in a neutral `fill` circle (docs/DESIGN.md §5): the leading element of a row,
/// an account's currency mark, a category. Replaces the pastel tinted icon tile. SF Symbols are drawn
/// in their outline form (see ``outlineSymbol(_:)``) so every row uses one glyph style.
///
/// ```swift
/// GlyphCircle(systemImage: "creditcard")          // SF Symbol, ink
/// GlyphCircle(text: "₽")                          // currency / monogram
/// GlyphCircle(currency: "USD")                    // RUB → ₽, USD → $, EUR → €, USDT → ₮
/// GlyphCircle(systemImage: "xmark", tint: theme.danger)   // semantic tint only
/// ```
struct GlyphCircle: View {
    private enum Mark { case symbol(String), text(String) }

    private let mark: Mark
    var size: CGFloat = 36
    /// Glyph color. Defaults to `textPrimary`. Pass a status color only when it carries meaning.
    var tint: Color? = nil
    /// Circle color. Defaults to `fill`.
    var background: Color? = nil

    @Environment(\.theme) private var theme

    init(systemImage: String, size: CGFloat = 36, tint: Color? = nil, background: Color? = nil) {
        self.mark = .symbol(systemImage)
        self.size = size
        self.tint = tint
        self.background = background
    }

    init(text: String, size: CGFloat = 36, tint: Color? = nil, background: Color? = nil) {
        self.mark = .text(text)
        self.size = size
        self.tint = tint
        self.background = background
    }

    /// Currency mark for an ISO code or ticker.
    init(currency code: String, size: CGFloat = 36) {
        self.init(text: GlyphCircle.currencyMark(code), size: size)
    }

    static func currencyMark(_ code: String) -> String {
        switch code.uppercased() {
        case "RUB", "RUR", "₽": return "₽"
        case "USD", "$":        return "$"
        case "EUR", "€":        return "€"
        case "CNY", "¥":        return "¥"
        case "GBP", "£":        return "£"
        case "USDT":            return "₮"
        case "BTC":             return "₿"
        case "ETH":             return "Ξ"
        case "DRUB":            return "Ц"
        default:                return String(code.prefix(1)).uppercased()
        }
    }

    /// One glyph style everywhere: outline symbols, no symbol-in-a-circle inside the circle.
    /// `lock.shield.fill` → `lock.shield`, `rublesign.circle.fill` → `rublesign`, when that symbol exists.
    static func outlineSymbol(_ name: String) -> String {
        var parts = name.split(separator: ".").map(String.init)
        let unfilled = parts.filter { $0 != "fill" }
        if unfilled.count != parts.count, UIImage(systemName: unfilled.joined(separator: ".")) != nil {
            parts = unfilled
        }
        if let last = parts.last, ["circle", "square"].contains(last), parts.count > 1 {
            let bare = parts.dropLast().joined(separator: ".")
            if UIImage(systemName: bare) != nil { return bare }
        }
        return parts.joined(separator: ".")
    }

    var body: some View {
        ZStack {
            Circle().fill(background ?? theme.fill)
            switch mark {
            case .symbol(let name):
                Image(systemName: GlyphCircle.outlineSymbol(name))
                    .font(.system(size: (size * 0.47).rounded(), weight: .regular))
                    .symbolRenderingMode(.monochrome)
            case .text(let text):
                Text(text)
                    .font(.system(size: (size * (text.count > 1 ? 0.36 : 0.47)).rounded(),
                                  weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(tint ?? theme.textPrimary)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        GlyphCircle(systemImage: "creditcard")
        GlyphCircle(currency: "RUB")
        GlyphCircle(currency: "USD")
        GlyphCircle(currency: "USDT")
        GlyphCircle(text: "АР")
        GlyphCircle(systemImage: "xmark", tint: Theme.default.danger)
    }
    .padding()
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
