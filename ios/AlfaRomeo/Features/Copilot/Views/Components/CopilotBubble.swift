import SwiftUI

/// One message row: a right-aligned accent bubble for the user; for the assistant, a cold-gradient
/// avatar beside a surface bubble that can also host an action card, a result receipt, or an escalation
/// pill (§10.9).
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
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
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
            Spacer(minLength: 28)
        }
    }

    private var showsTyping: Bool {
        message.isStreaming && message.text.isEmpty && message.draft == nil && message.result == nil
    }

    private var avatar: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(theme.cryptoGradient, in: Circle())
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
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}
