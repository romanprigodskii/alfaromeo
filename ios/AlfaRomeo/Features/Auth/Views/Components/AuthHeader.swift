import SwiftUI

/// Title + optional subtitle used across the pre-auth screens.
struct AuthHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(BrandFont.displayL)
                .foregroundStyle(theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
