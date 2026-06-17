import SwiftUI

/// Chat input bar (§10.9): a growing pill text field, a gradient send button, and a one-tap escalation
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
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Позвать человека").font(BrandFont.micro.weight(.medium))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(theme.elevated, in: Capsule())
                    .overlay(Capsule().stroke(theme.border, lineWidth: 1))
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
                    .background(theme.elevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.border, lineWidth: 1))

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            canSend ? AnyShapeStyle(theme.cryptoGradient) : AnyShapeStyle(theme.border),
                            in: Circle()
                        )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canSend)
                .accessibilityLabel("Отправить")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(theme.surface)
        .overlay(alignment: .top) { Rectangle().fill(theme.border).frame(height: 1) }
    }
}
