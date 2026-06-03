import SwiftUI

/// «В меню» exit for the credit flow (§10.5). The credit screens are pushed onto the Home stack, so the
/// system back goes one level; this adds a one-tap exit straight back to Главный from ANY credit page
/// (hub / pre-qual / apply / status). Pops the whole pushed path via the section ``Router``.
struct CreditExitToolbar: ViewModifier {
    @Environment(Router.self) private var router

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.popToRoot() } label: {
                    Image(systemName: "house")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("На главный экран")
                .accessibilityHint("Выйти из раздела кредитов в меню")
            }
        }
    }
}

extension View {
    /// Adds the «в меню» exit button to a pushed credit screen (§10.5).
    func creditExitToolbar() -> some View { modifier(CreditExitToolbar()) }
}
