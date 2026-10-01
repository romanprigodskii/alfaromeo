import SwiftUI

/// One tab section: an isolated `NavigationStack` driven by its own ``Router`` (per-tab coordinator
/// pin, §9), wrapped in the persistent shell chrome — the navbar avatar (→ profile switcher) and the
/// floating AI-copilot button.
///
/// The `root` view (a feature module's section root) supplies **both** its content and its
/// `.navigationDestination(...)` handlers, so each Phase-1 module (Home / Payments / History) wires
/// its own routes without ever touching this shell. The section ``Router`` is injected into the
/// environment for the root — and anything it pushes — to read via `@Environment(Router.self)`.
struct SectionScaffold<Root: View>: View {
    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @ViewBuilder var root: () -> Root

    @Environment(ShellState.self) private var shell
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            root()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(titleDisplayMode)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { AvatarButton() }
                }
        }
        // The section's coordinator. Injected here so the root view — and any destination it pushes —
        // can `push`/`pop` without binding-drilling (mirrors the AppSession / ShellState DI style).
        .environment(router)
        // Persistent floating AI-copilot button. As an overlay on the NavigationStack, its
        // bottom-trailing anchor sits just above the tab bar on every device — the stack's safe
        // area is already inset by the tab bar, so no magic offset is needed.
        .overlay(alignment: .bottomTrailing) {
            AICopilotButton { shell.showCopilot() }
                .padding(.trailing, Spacing.screen)
                .padding(.bottom, Spacing.md)
        }
    }
}
