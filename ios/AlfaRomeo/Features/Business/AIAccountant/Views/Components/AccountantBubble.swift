import SwiftUI

/// One message row in the AI-бухгалтер chat (§8.2). The business twin of ``CopilotBubble``: a
/// right-aligned accent bubble for the user; for the assistant, a neutral «AI» monogram beside a surface
/// bubble that can host streamed text (typing indicator), a business action card, a result receipt, or
/// an escalation pill. Reuses ``CopilotTypingIndicator`` / ``StatusPill`` and the shared message model.
struct AccountantBubble: View {
    let message: CopilotMessage
    var onConfirm: (AIToolDraft) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        switch message.role {
        case .user:      userBubble
        case .assistant: assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 44)
            Text(message.text)
                .font(BrandFont.body())
                .foregroundStyle(theme.onAccent)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            avatar
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showsTyping {
                    CopilotTypingIndicator()
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                } else if !message.text.isEmpty {
                    Text(message.text)
                        .font(BrandFont.body())
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                }

                if let draft = message.draft {
                    AccountantActionCard(draft: draft) { onConfirm(draft) }
                }
                if let result = message.result {
                    resultRow(result)
                }
                if message.escalated {
                    StatusPill(status: .pending, text: "Специалист подключится")
                }
            }
            Spacer(minLength: 28)
        }
    }

    private var showsTyping: Bool {
        message.isStreaming && message.text.isEmpty && message.draft == nil && message.result == nil
    }

    private var avatar: some View {
        GlyphCircle(text: "AI", size: 30)
            .accessibilityHidden(true)
    }

    private func resultRow(_ receipt: CopilotActionReceipt) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            StatusPill(status: receipt.outcome == .executed ? .success : .declined)
            Text(receipt.message)
                .font(BrandFont.callout)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
