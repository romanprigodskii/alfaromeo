import SwiftUI

/// Chat input bar (§10.9): a growing text field, a flat accent send button, and a one-tap escalation
/// to a human operator («позвать человека»). A hairline at the top separates the bar from the transcript.
struct CopilotComposer: View {
    @Binding var text: String
    var isStreaming: Bool
    var onSend: () -> Void
    var onEscalate: () -> Void

    @Environment(\.theme) private var theme

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Button(action: onEscalate) {
                    Text("Позвать человека")
                        .font(BrandFont.footnote.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, Spacing.md - 4)
                        .padding(.vertical, 6)
                        .background(theme.fill, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isStreaming)
                .opacity(isStreaming ? 0.5 : 1)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Спросите Claude…", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .stroke(theme.border, lineWidth: 0.5))

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSend ? theme.onAccent : theme.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(canSend ? theme.accent : theme.fill, in: Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canSend)
                .accessibilityLabel("Отправить")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(theme.surface)
        .overlay(alignment: .top) { Hairline() }
    }
}
