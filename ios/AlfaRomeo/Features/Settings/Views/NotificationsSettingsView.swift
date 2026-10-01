import SwiftUI

/// Уведомления (§9.8): push channels. Toggles persist in ``SettingsStore`` (demo: no real push
/// registration yet).
struct NotificationsSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                GroupedSection {
                    SettingsToggleRow(icon: "bell", title: "Push-уведомления",
                                      subtitle: "Все каналы", isOn: $settings.notifyPush)
                }

                GroupedSection("Каналы", footer: "Канал «Безопасность» рекомендуем держать включённым.") {
                    SettingsToggleRow(icon: "arrow.left.arrow.right", title: "Операции и платежи",
                                      subtitle: "Списания, поступления, статусы", isOn: $settings.notifyTransactions)
                        .disabled(!settings.notifyPush)
                    SettingsToggleRow(icon: "lock.shield", title: "Безопасность",
                                      subtitle: "Входы, новые устройства, подтверждения", isOn: $settings.notifySecurity)
                        .disabled(!settings.notifyPush)
                    SettingsToggleRow(icon: "tag", title: "Акции и предложения",
                                      subtitle: "Кэшбек, тарифы, партнёры", isOn: $settings.notifyMarketing)
                        .disabled(!settings.notifyPush)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.snappy, value: settings.notifyPush)
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
        .environment(\.theme, .default)
}
