import SwiftUI

/// AI-инсайт строкой on the business дашборд (§8.2 / §10.2, DESIGN §7): the AI-бухгалтер's headline
/// (the cash-gap warning with a sum + date, or an all-clear) as a plain line with a trailing «Спросить»
/// link. Tapping it opens ``AIAccountantView`` (the Чаты(AI) tab), where the same scenario is grounded
/// in the live chat. No sparkles, no gradient border.
struct DashboardAIInsightCard: View {
    let title: String
    let message: String
    let cta: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.sm + 4) {
                GlyphCircle(text: "AI")
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(message)
                        .font(BrandFont.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(cta)
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AI-бухгалтер. \(title). \(message)")
        .accessibilityHint("Открыть AI-бухгалтера")
        .accessibilityAddTraits(.isButton)
    }
}
