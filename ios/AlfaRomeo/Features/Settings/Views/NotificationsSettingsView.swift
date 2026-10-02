import SwiftUI

/// Уведомления (§9.8): push channels. Toggles persist in ``SettingsStore`` (demo: no real push
/// registration yet).
struct NotificationsSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared
    @State private var alerts = PriceAlertsStore.shared

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

                priceAlerts
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

    /// Ценовые алерты from «Биржа» (crypto and Мосбиржа), all assets; swipe left to delete.
    private var priceAlerts: some View {
        let list = alerts.allSorted
        return GroupedSection("Ценовые алерты",
                              footer: list.isEmpty ? nil : "Срабатывают только по живым ценам. Смахните алерт влево, чтобы удалить.") {
            if list.isEmpty {
                ListRow(icon: "bell", title: "Алертов пока нет",
                        subtitle: "Создайте на странице актива в «Бирже»")
            } else {
                ForEach(list) { alert in
                    SwipeToDeleteRow { alerts.delete(alert.id) } content: {
                        PriceAlertRow(alert: alert, showsAsset: true)
                    }
                }
            }
        }
        .animation(Motion.snappy, value: list.map(\.id))
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
        .environment(\.theme, .default)
}
