import SwiftUI

/// AI-инсайт строкой at the top of the business дашборд (§8.2 / §10.2). A tappable «cold» AI surface
/// (§13.1 crypto/AI gradient) that surfaces the AI-бухгалтер's headline — the cash-gap warning with a
/// sum + date, or an all-clear — and leads straight into ``AIAccountantView`` (the Чаты(AI) tab), where
/// the same scenario is grounded in the live chat.
struct DashboardAIInsightCard: View {
    let title: String
    let message: String
    let cta: String
    let action: () -> Void

    @Environment(\.theme) private var theme

    private var coldBackdrop: Color { (theme.accentCrypto.first ?? theme.accent).opacity(0.14) }
    private var coldBadge: Color { theme.accentCrypto.last ?? theme.accent }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.cryptoGradient)
                        .frame(width: 36, height: 36)
                        .background(coldBackdrop, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.sm) {
                            Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                            Badge(kind: .text("AI-бухгалтер"), tint: coldBadge)
                        }
                        Text(message)
                            .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }

                HStack(spacing: Spacing.xxs) {
                    Text(cta).font(BrandFont.caption.weight(.semibold))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(theme.accent)
                .padding(.leading, 36 + Spacing.md)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(theme.cryptoGradient.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
