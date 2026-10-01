import SwiftUI

/// Persistent floating AI-copilot button (§9). A plain monochrome glyph on a surface circle
/// (docs/DESIGN.md §7: no sparkles, no gradient). As a floating element it carries the one soft shadow.
struct AICopilotButton: View {
    var action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: "text.bubble")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 56, height: 56)
                .background(theme.surface, in: Circle())
                .overlay(Circle().stroke(theme.border, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("AI-копилот")
    }
}
