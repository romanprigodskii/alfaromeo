import SwiftUI

/// Soft upsell shown when a feature is gated by tier (§4 — "мягко, без тёмных паттернов").
/// Informative, optional, and offers a clear path to the subscription screen. Never blocks.
struct UpsellCard: View {
    let title: String
    let message: String
    var recommendedTier: Tier = .pro

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accentCrypto.first ?? theme.accent)
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
            }
            Text(message)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                SubscriptionView()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text("Повысить до \(recommendedTier.shortLabel)")
                    Image(systemName: "arrow.right")
                }
                .font(BrandFont.callout.weight(.semibold))
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.accent.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
