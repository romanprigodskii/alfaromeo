import Observation

/// Lightweight UI coordinator for shell-level presentations — the persistent AI copilot and the
/// profile switcher. Injected via the environment so deep nav-bar / overlay buttons can trigger
/// them without binding drilling (§9).
@MainActor
@Observable
final class ShellState {
    enum Sheet: Identifiable, Hashable {
        case copilot(CopilotLaunch)
        case profileSwitcher
        var id: Self { self }
    }

    var sheet: Sheet?

    /// Open the AI copilot. The optional ``CopilotLaunch`` carries the mode + pre-seeded context for
    /// contextual entry points (a History operation, a declined op); the floating button uses `.standard`.
    func showCopilot(_ launch: CopilotLaunch = .standard) { sheet = .copilot(launch) }
    func showProfileSwitcher() { sheet = .profileSwitcher }
    func dismiss() { sheet = nil }
}
