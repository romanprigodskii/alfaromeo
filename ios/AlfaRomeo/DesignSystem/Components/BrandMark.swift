import SwiftUI

/// The «Альфа-Ромео» wordmark (splash, onboarding). Bold SF Pro, ink; an optional quiet subtitle in
/// sentence case. No letter-spaced caps.
struct BrandMark: View {
    @Environment(\.theme) private var theme
    var subtitle: String? = "банк 2035"

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                // The brand slab: one solid block of heritage red, no gloss.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.accent)
                    .frame(width: 10, height: 26)
                Text("Альфа-Ромео")
                    .font(BrandFont.display(34, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(BrandFont.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Альфа-Ромео")
    }
}

#Preview {
    ZStack {
        Theme.default.background.ignoresSafeArea()
        BrandMark()
    }
    .environment(\.theme, .default)
}
