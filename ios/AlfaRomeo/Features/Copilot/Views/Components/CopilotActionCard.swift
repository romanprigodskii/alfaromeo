import SwiftUI

/// In-chat confirmation card for an agent action draft (§11.7). Shows the proposed action's details (and
/// a blocked note when a guardrail tripped) as one flat surface card. The button opens the biometric
/// confirm flow; the AI never moves money on its own.
struct CopilotActionCard: View {
    let draft: AIToolDraft
    var onConfirm: () -> Void

    @Environment(\.theme) private var theme

    private var biometry: String { BiometricAuthenticator.available().label }

    private var icon: String {
        switch draft.tool {
        case "make_transfer": return "arrow.up.right"
        case "open_deposit":  return "banknote"
        case "freeze_card":   return "snowflake"
        default:              return "checklist"
        }
    }

    private var title: String {
        switch draft.tool {
        case "make_transfer": return "Перевод"
        case "open_deposit":  return "Вклад"
        case "freeze_card":   return "Заморозка карты"
        default:              return "Действие"
        }
    }

    private var symbol: String {
        guard let c = draft.currency, c != "RUB" else { return "₽" }
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                GlyphCircle(systemImage: icon, size: 36)
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("Черновик").font(BrandFont.footnote).foregroundStyle(theme.textSecondary)
            }

            Text(draft.summary)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let amount = draft.amount {
                AmountText(amount: amount, currency: symbol, size: 22)
            }

            if draft.blocked {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(BrandFont.footnote)
                        .foregroundStyle(theme.warning)
                    Text(draft.blockReason ?? "Действие заблокировано гардрейлами AI.")
                        .font(BrandFont.footnote)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            PrimaryButton(
                title: draft.blocked ? "Недоступно" : "Подтвердить · \(biometry)",
                icon: draft.blocked ? "lock.slash" : "faceid",
                action: onConfirm
            )
            .disabled(draft.blocked)

            Text("AI не двигает деньги. Действие выполняете вы: тапом и биометрией.")
                .font(BrandFont.footnote)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
