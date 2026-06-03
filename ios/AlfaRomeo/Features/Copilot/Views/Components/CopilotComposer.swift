import SwiftUI

/// Chat input bar (§10.9): a growing text field, a gradient send button, and a one-tap escalation to a
/// human operator («позвать человека»).
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
                    Label("Позвать человека", systemImage: "person.fill.questionmark")
                        .font(BrandFont.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .disabled(isStreaming)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                TextField("Спросите что угодно…", text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .font(BrandFont.body())
                    .foregroundStyle(theme.textPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )

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
        .padding(Spacing.md)
        .background(theme.surface)
    }
}
