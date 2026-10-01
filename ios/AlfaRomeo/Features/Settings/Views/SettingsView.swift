import SwiftUI

/// Настройки (§9.8): Безопасность, Уведомления, Тема, Язык, Подписка. Each row pushes its screen
/// in the surrounding navigation stack; Тема/Язык show the current choice inline. Backed by the
/// persisted ``SettingsStore``.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                GroupedSection {
                    link(icon: "lock.shield", title: "Безопасность",
                         subtitle: "Face ID, код-пароль, устройства") { SecuritySettingsView() }
                    link(icon: "bell", title: "Уведомления",
                         value: settings.notifyPush ? "Вкл." : "Выкл.") { NotificationsSettingsView() }
                }

                GroupedSection {
                    link(icon: "circle.lefthalf.filled", title: "Тема",
                         value: settings.themePreference.label) { ThemeSettingsView() }
                    link(icon: "globe", title: "Язык",
                         value: settings.language.label) { LanguageSettingsView() }
                }

                GroupedSection(footer: "Настройки сохраняются на устройстве. Тема меняет оформление всего приложения.") {
                    link(icon: "star", title: "Подписка",
                         subtitle: "Тариф и привилегии") { SubscriptionView() }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    private func link<Destination: View>(icon: String, title: String,
                                         subtitle: String? = nil, value: String? = nil,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            ListRow(icon: icon, title: title, subtitle: subtitle, value: value, showsChevron: true)
        }
        .buttonStyle(.row)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
