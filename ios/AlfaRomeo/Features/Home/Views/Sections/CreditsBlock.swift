import SwiftUI

/// Credit teaser (§9.1, §10.5): a pre-approved amount with an explainable-AI hint. Opens the credit
/// stub (``HomeRoute.credits``).
struct CreditsBlock: View {
    let amount: Double
    var onTap: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        DashboardSection(title: "Кредит") {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StatusPill(status: .success, text: "Преодобрено")
                    Text("Вам одобрено до").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    AmountText(amount: amount, size: 28)
                    Text("Объясним решение и покажем симулятор платежа (§10.5).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    PrimaryButton(title: "Оформить", icon: "arrow.right", action: onTap)
                }
            }
        }
    }
}
