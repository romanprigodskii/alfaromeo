import SwiftUI

/// Title + optional subtitle used across the pre-auth screens.
struct AuthHeader: View {
    let title: String
    var subtitle: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BrandFont.title1)
                .foregroundStyle(theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
