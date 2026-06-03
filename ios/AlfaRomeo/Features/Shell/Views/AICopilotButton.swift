import SwiftUI

/// Persistent floating AI-copilot button (§9). Uses the cold crypto/AI gradient to read as "AI".
struct AICopilotButton: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(theme.cryptoGradient, in: Circle())
                .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("AI-копилот")
    }
}
