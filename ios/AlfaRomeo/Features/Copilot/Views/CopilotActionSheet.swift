import SwiftUI

/// The biometric confirm + status surface for an agent action draft (§11.7). Opened from the in-chat
/// action card: it immediately runs Face ID, shows the animated processing state (reusing
/// ``OperationStatusView``), then the result (``StatusPill`` + the server receipt). The AI proposed the
/// draft; the user authorises and the server executes (simulated).
struct CopilotActionSheet: View {
    var onFinish: (CopilotActionReceipt) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var model: CopilotActionModel

    init(draft: AIToolDraft, profileId: String, onFinish: @escaping (CopilotActionReceipt) -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: CopilotActionModel(draft: draft, profileId: profileId))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.background)
            .task {
                // Go straight to Face ID when the sheet opens (the confirm card was already shown in chat).
                if case .confirm = model.phase { await model.confirm() }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .confirm, .authorizing, .processing:
            OperationStatusView(
                outcome: .processing,
                amount: model.draft.amount ?? 0,
                currency: symbol,
                recipientName: recipientLabel,
                onRetry: {},
                onClose: { dismiss() }
            )
        case .done(let result):
            resultView(result)
        }
    }

    private func resultView(_ result: AIConfirmResult) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.xl)

            Image(systemName: result.isExecuted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(result.isExecuted ? theme.success : theme.danger)

            StatusPill(status: result.isExecuted ? .success : .declined)

            Text(result.message)
                .font(BrandFont.title)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.lg)

            if let reason = result.reason, !result.isExecuted, reason != "biometric" {
                Text(reason)
                    .font(BrandFont.callout)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.lg)
            }

            Spacer(minLength: Spacing.lg)

            PrimaryButton(title: "Готово", icon: "checkmark") { finish(result) }
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.xl)
    }

    private func finish(_ result: AIConfirmResult) {
        onFinish(CopilotActionReceipt(
            outcome: result.isExecuted ? .executed : .declined,
            message: result.message
        ))
        dismiss()
    }

    private var symbol: String {
        guard let c = model.draft.currency, c != "RUB" else { return "₽" }
        return c
    }

    private var recipientLabel: String {
        switch model.draft.tool {
        case "make_transfer": return model.draft.params["to"]?.stringValue ?? "Получатель"
        case "open_deposit":  return "Вклад"
        case "freeze_card":   return "Карта"
        default:              return "Операция"
        }
    }
}
