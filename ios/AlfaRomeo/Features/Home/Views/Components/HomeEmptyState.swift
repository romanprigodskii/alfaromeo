import SwiftUI

/// Onboarding empty state for a profile with no money objects (§10.2 «пустой профиль»). Offers the
/// two first products — a card and a crypto wallet (§6.2, §9.6).
struct HomeEmptyState: View {
    var onOpenCard: () -> Void
    var onOpenWallet: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Добро пожаловать").font(BrandFont.displayL).foregroundStyle(theme.textPrimary)
                Text("Откройте первый продукт — это займёт секунды.")
                    .font(BrandFont.body()).foregroundStyle(theme.textSecondary)
            }

            onboardingCard(
                icon: "creditcard.fill",
                title: "Открыть карту",
                subtitle: "Виртуальная — мгновенно, сразу в Apple Pay (§6.2).",
                cta: "Заказать карту",
                action: onOpenCard
            )

            onboardingCard(
                icon: "bitcoinsign.circle.fill",
                title: "Открыть крипто-кошелёк",
                subtitle: "₽, цифровой ₽ и крипта в одном кошельке (§9.6).",
                gradient: theme.cryptoGradient,
                cta: "Создать кошелёк",
                action: onOpenWallet
            )
        }
    }

    @ViewBuilder
    private func onboardingCard(icon: String, title: String, subtitle: String,
                                gradient: LinearGradient? = nil,
                                cta: String, action: @escaping () -> Void) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.md) {
                    iconChip(icon, gradient: gradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                }
                PrimaryButton(title: cta, action: action)
            }
        }
    }

    @ViewBuilder
    private func iconChip(_ icon: String, gradient: LinearGradient?) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(gradient == nil ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.white))
            .frame(width: 44, height: 44)
            .background {
                if let gradient { shape.fill(gradient) } else { shape.fill(theme.accent.opacity(0.14)) }
            }
    }
}
