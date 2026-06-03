import SwiftUI

/// Navbar avatar — opens the profile switcher (§5.2). Ringed with the active theme accent.
/// The 32pt avatar is centered in a 44pt hit target (HIG / WCAG 2.5.5).
struct AvatarButton: View {
    @Environment(AppSession.self) private var session
    @Environment(ShellState.self) private var shell
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            shell.showProfileSwitcher()
        } label: {
            Avatar(initials: session.avatarInitials, size: 32, ringColor: theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Профиль")
        .accessibilityHint("Открыть переключатель профилей")
    }
}
