import SwiftUI

/// One message row: a right-aligned accent bubble for the user; for the assistant, a monochrome «AI»
/// monogram beside a surface bubble that can also host an action card, a result receipt, or an escalation
/// pill (§10.9). Bubbles carry a small tail on the sender's side and a generous opposite-side inset.
struct CopilotBubble: View {
    let message: CopilotMessage
    var onConfirm: (AIToolDraft) -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        switch message.role {
        case .user:      userBubble
        case .assistant: assistantBubble
        }
    }

    /// Speech-bubble corners: rounded on three corners with a small tail on the sender's side.
    private func bubbleShape(isUser: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: Radius.lg,
            bottomLeadingRadius: isUser ? Radius.lg : Radius.xs,
            bottomTrailingRadius: isUser ? Radius.xs : Radius.lg,
            topTrailingRadius: Radius.lg,
            style: .continuous)
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 56)
            Text(message.text)
                .font(BrandFont.body())
                .foregroundStyle(theme.onAccent)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(theme.accent, in: bubbleShape(isUser: true))
        }
    }

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            avatar
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if showsTyping {
                    CopilotTypingIndicator()
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .background(theme.surface, in: bubbleShape(isUser: false))
                } else if !message.text.isEmpty {
                    Text(message.text)
                        .font(BrandFont.body())
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.surface, in: bubbleShape(isUser: false))
                }

                if let draft = message.draft {
                    CopilotActionCard(draft: draft) { onConfirm(draft) }
                }
                if let result = message.result {
                    resultRow(result)
                }
                if message.escalated {
                    StatusPill(status: .pending, text: "Оператор подключится")
                }
            }
            Spacer(minLength: 44)
        }
    }

    private var showsTyping: Bool {
        message.isStreaming && message.text.isEmpty && message.draft == nil && message.result == nil
    }

    private var avatar: some View {
        GlyphCircle(text: "AI", size: 30)
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
