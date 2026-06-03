import SwiftUI

/// In-chat confirmation card for a business agent draft (§8.2) — `create_invoice` (входящий, дебиторка)
/// or `pay_supplier` (исходящий). Same contract as the personal ``CopilotActionCard``: it shows the
/// proposed action + amount, a blocked banner when a guardrail tripped (e.g. a large payment needing a
/// second signature), and a biometric confirm button. The AI proposes; the user executes.
struct AccountantActionCard: View {
    let draft: AIToolDraft
    var onConfirm: () -> Void

    @Environment(\.theme) private var theme

    private var biometry: String { BiometricAuthenticator.available().label }

    private var isInvoice: Bool { draft.tool == "create_invoice" }

    private var icon: String { isInvoice ? "doc.text.fill" : "arrow.up.right" }

    private var title: String {
        switch draft.tool {
        case "create_invoice": return "Счёт контрагенту"
        case "pay_supplier":   return "Оплата поставщику"
        default:               return "Действие"
        }
    }

    /// One-word flow direction so the user instantly sees money-in vs money-out.
    private var flowTag: String { isInvoice ? "входящий" : "исходящий" }

    /// Tool-aware reassurance: issuing an invoice moves no money; a supplier payment does — but only
    /// after the user's own biometric confirm (the AI proposes, the user executes — §8.2/§11.7).
    private var disclaimer: String {
        isInvoice
            ? "AI не двигает деньги — счёт выставляете вы тапом и биометрией."
            : "AI не двигает деньги — оплату подтверждаете вы тапом и биометрией."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(theme.cryptoGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                    Text(flowTag + " платёж").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Text("Черновик").font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }

            Text(draft.summary)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let amount = draft.amount {
                AmountText(amount: amount, currency: "₽", size: 22)
            }

            if draft.blocked {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.warning)
                    Text(draft.blockReason ?? "Сумма превышает лимит AI-агента — требуется подтверждение оператора.")
                        .font(BrandFont.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }

            PrimaryButton(
                title: draft.blocked ? "Нужна вторая подпись" : "Подтвердить · \(biometry)",
                icon: draft.blocked ? "lock.slash" : "faceid",
                action: onConfirm
            )
            .disabled(draft.blocked)

            Text(disclaimer)
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
