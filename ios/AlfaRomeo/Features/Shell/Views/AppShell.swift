import SwiftUI

/// The authenticated shell: the mode-appropriate tab bar (personal vs business, by
/// `activeProfile.type`) and the shell-level sheets (AI copilot + profile switcher).
///
/// The persistent floating AI-copilot button lives in ``SectionScaffold`` so it lays out above the
/// real tab bar on every device; ``ShellState`` (injected here) lets it and the navbar avatar
/// drive these sheets.
struct AppShell: View {
    @Environment(AppSession.self) private var session
    @State private var shell = ShellState()
    @State private var settings = SettingsStore.shared

    var body: some View {
        @Bindable var shell = shell

        ZStack {
            if session.isBusinessMode {
                BusinessTabView().transition(.opacity)
            } else {
                MainTabView().transition(.opacity)
            }
        }
        // Gentle crossfade on profile-mode swap. The two modes are different IA, so each mode's
        // per-tab navigation state intentionally resets — the real profile switcher will decide
        // whether to restore it.
        .animation(Motion.smooth, value: session.isBusinessMode)
        .environment(shell)
        .sheet(item: $shell.sheet) { sheet in
            Group {
                switch sheet {
                case .copilot(let launch): AICopilotSheet(launch: launch)
                case .profileSwitcher:     ProfileSwitcherSheet()
                }
            }
            // A `.sheet` presents content with the environment of the node it's attached to — which is
            // *above* the `.environment(shell)` below, so `ShellState` would not reach the presented
            // sheet. Re-inject the same coordinator so the shell-level sheets can call `shell.dismiss()`.
            .environment(shell)
            // Re-resolve the theme inside the sheet so it re-themes live with the profile toggle and
            // the user's theme preference (§9.8) — `nil` follows the device.
            .themeProvider(profileType: session.activeProfile?.type,
                           scheme: settings.themePreference.preferredColorScheme)
        }
    }
}
