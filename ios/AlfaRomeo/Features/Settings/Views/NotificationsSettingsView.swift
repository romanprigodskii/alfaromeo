import SwiftUI

/// Уведомления (§9.8) — push channels. Toggles persist in ``SettingsStore`` (demo: no real push
/// registration yet).
struct NotificationsSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard(padding: Spacing.md) {
                    VStack(spacing: Spacing.md) {
                        row(icon: "bell.badge.fill", title: "Push-уведомления",
                            subtitle: "Главный выключатель", isOn: $settings.notifyPush)
                        Divider().overlay(theme.border)
                        row(icon: "arrow.left.arrow.right", title: "Операции и платежи",
                            subtitle: "Списания, поступления, статусы", isOn: $settings.notifyTransactions)
                            .disabled(!settings.notifyPush)
                        Divider().overlay(theme.border)
                        row(icon: "lock.shield.fill", title: "Безопасность",
                            subtitle: "Входы, новые устройства, подтверждения", isOn: $settings.notifySecurity)
                            .disabled(!settings.notifyPush)
                        Divider().overlay(theme.border)
                        row(icon: "tag.fill", title: "Акции и предложения",
                            subtitle: "Кэшбек, тарифы, партнёрские офферы", isOn: $settings.notifyMarketing)
                            .disabled(!settings.notifyPush)
                    }
                }
                Text("Канал «Безопасность» рекомендуем держать включённым.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
        .opacity(1)
        .animation(.snappy, value: settings.notifyPush)
    }

    private func row(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
            }
        }
        .tint(theme.accent)
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
        .environment(\.theme, .default)
}
