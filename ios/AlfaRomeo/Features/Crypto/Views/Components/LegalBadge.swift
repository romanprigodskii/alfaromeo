import SwiftUI

/// «ЦФА · 259-ФЗ · легально» — the legal stamp on the digital-financial-asset path (§2.4 narrative:
/// ЦФА is the white, already-legal route, distinct from crypto). Cold gradient pill so it visually
/// belongs to the digital-asset family while signalling its regulated status.
struct LegalBadge: View {
    var text: String = "ЦФА · 259-ФЗ · легально"
    var compact: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
            Text(text)
                .font(compact ? BrandFont.micro : BrandFont.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? Spacing.sm : Spacing.md)
        .padding(.vertical, compact ? 3 : Spacing.xs)
        .background(theme.cryptoGradient, in: Capsule())
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
