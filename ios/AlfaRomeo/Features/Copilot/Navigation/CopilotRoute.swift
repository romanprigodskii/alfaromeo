import SwiftUI

/// Navigation routes for the copilot channel inside the Chats tab (§9.5). Pushed onto the section
/// ``Router`` and resolved by ``ChatsHubView``.
enum CopilotRoute: Hashable {
    case chat(CopilotLaunch)
}

extension CopilotRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .chat(let launch): CopilotChatView(launch: launch, embedded: true)
        }
    }
}
