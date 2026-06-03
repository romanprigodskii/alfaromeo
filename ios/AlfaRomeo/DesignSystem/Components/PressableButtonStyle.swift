import SwiftUI

/// Shared press feedback: subtle scale + opacity, restrained per §13.1. Honors Reduce Motion —
/// when on, the scale and animation are dropped (opacity-only, instant).
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        Label(configuration: configuration, pressedScale: pressedScale)
    }

    private struct Label: View {
        let configuration: Configuration
        let pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? pressedScale : 1))
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(reduceMotion ? nil : Motion.snappy, value: configuration.isPressed)
        }
    }
}
