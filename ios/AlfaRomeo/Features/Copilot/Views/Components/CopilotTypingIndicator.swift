import SwiftUI

/// Three-dot «печатает…» indicator shown in the assistant bubble while the first tokens are in flight.
struct CopilotTypingIndicator: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.textSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 0.6 : (phase == i ? 1 : 0.3))
                    .scaleEffect(reduceMotion ? 1 : (phase == i ? 1 : 0.7))
            }
        }
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.26)) { phase = (phase + 1) % 3 }
        }
        .accessibilityLabel("Печатает")
    }
}
