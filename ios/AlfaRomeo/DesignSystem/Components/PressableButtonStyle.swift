import SwiftUI

/// Shared press feedback: a slight scale + dim, ease-out, no bounce (docs/DESIGN.md §9). Honors
/// Reduce Motion: the scale and animation are dropped (dim only, instant).
struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98

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
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(reduceMotion ? nil : Motion.snappy, value: configuration.isPressed)
        }
    }
}
