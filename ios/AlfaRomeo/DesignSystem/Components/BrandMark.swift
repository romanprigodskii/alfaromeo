import SwiftUI

/// The «Альфа-Ромео» wordmark used on the splash/placeholder. Theme-aware.
struct BrandMark: View {
    @Environment(\.theme) private var theme
    var subtitle: String? = "банк 2035"

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Альфа-Ромео")
                .font(BrandFont.display(40))
                .foregroundStyle(theme.textPrimary)
                .tracking(0.5)

            if let subtitle {
                Text(subtitle)
                    .font(BrandFont.mono(13, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .textCase(.uppercase)
                    .tracking(4)
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
}
