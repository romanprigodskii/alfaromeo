import SwiftUI

/// In-chat confirmation card for an agent action draft (§11.7). Shows the proposed action's details (and
/// a blocked banner when a guardrail tripped), framed with the cold AI gradient. The button opens the
/// biometric confirm flow — the AI never moves money on its own.
struct CopilotActionCard: View {
    let draft: AIToolDraft
    var onConfirm: () -> Void

    @Environment(\.theme) private var theme

    private var biometry: String { BiometricAuthenticator.available().label }

    private var icon: String {
        switch draft.tool {
        case "make_transfer": return "arrow.up.right"
        case "open_deposit":  return "banknote.fill"
        case "freeze_card":   return "snowflake"
        default:              return "wand.and.stars"
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
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                Spacer()
                Text("Черновик").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }

            Text(draft.summary)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let amount = draft.amount {
                AmountText(amount: amount, currency: symbol, size: 22)
            }

            if draft.blocked {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.warning)
                    Text(draft.blockReason ?? "Действие заблокировано гардрейлами AI.")
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }

            PrimaryButton(
                title: draft.blocked ? "Недоступно" : "Подтвердить · \(biometry)",
                icon: draft.blocked ? "lock.slash" : "faceid",
                action: onConfirm
            )
            .disabled(draft.blocked)

            Text("AI не двигает деньги — действие выполняете вы тапом и биометрией.")
                .font(BrandFont.micro)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.md)
        .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.cryptoGradient, lineWidth: 1.5)
        )
    }
}
