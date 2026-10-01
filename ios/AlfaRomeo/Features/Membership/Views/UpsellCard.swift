import SwiftUI

/// Soft upsell shown when a feature is gated by tier (§4: "мягко, без тёмных паттернов").
/// Informative, optional, and offers a clear path to the subscription screen. Never blocks.
struct UpsellCard: View {
    let title: String
    let message: String
    var recommendedTier: Tier = .pro

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            Text(message)
                .font(BrandFont.subheadline)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                SubscriptionView()
            } label: {
                Text("Повысить до \(recommendedTier.shortLabel)")
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
