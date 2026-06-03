import SwiftUI

/// Sheet host for the AI copilot (§10.9), presented from the floating button and contextual entry points.
/// The chat itself lives in ``CopilotChatView``; this wrapper only supplies the sheet presentation.
struct AICopilotSheet: View {
    var launch: CopilotLaunch = .standard

    @Environment(\.theme) private var theme

    var body: some View {
        CopilotChatView(launch: launch, embedded: false)
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(theme.background)
    }
}
