import SwiftUI

/// Mode switcher (§10.9): Поддержка / Финкоуч / Агент. A native segmented control (docs/DESIGN.md §5):
/// flat, no gradient, the same look as every other segmented choice in the app.
struct CopilotModePicker: View {
    @Binding var mode: CopilotMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Picker("Режим", selection: Binding(
            get: { mode },
            set: { new in withAnimation(reduceMotion ? nil : Motion.snappy) { mode = new } }
        )) {
            ForEach(CopilotMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
