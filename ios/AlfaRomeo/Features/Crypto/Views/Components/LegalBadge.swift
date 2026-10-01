import SwiftUI

/// «ЦФА по 259-ФЗ»: the legal stamp on the digital-financial-asset path (§2.4 narrative: ЦФА is the
/// white, already-legal route, distinct from crypto). A neutral badge (caption 12 medium, radius 8,
/// `fill`) with a seal glyph; no tint, it is a fact, not a state.
struct LegalBadge: View {
    var text: String = "ЦФА по 259-ФЗ"
    var compact: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: compact ? 11 : 13, weight: .regular))
            Text(text)
                .font(compact ? BrandFont.micro : BrandFont.footnote.weight(.medium))
        }
        .foregroundStyle(theme.textPrimary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, compact ? 2 : Spacing.xs)
        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityLabel("ЦФА, по 259-ФЗ, легальный инструмент")
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        LegalBadge()
        LegalBadge(text: "259-ФЗ", compact: true)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.default.background)
    .environment(\.theme, .default)
}
