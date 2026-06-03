import SwiftUI

/// Настройки (§9.8): Безопасность · Уведомления · Тема · Язык · Подписка. Each row pushes its screen
/// in the surrounding navigation stack; Тема/Язык show the current choice inline. Backed by the
/// persisted ``SettingsStore``.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                section {
                    link(icon: "lock.shield.fill", tint: theme.accent, title: "Безопасность",
                         subtitle: "Face ID, PIN, passkeys, устройства, лимиты") { SecuritySettingsView() }
                    Divider().overlay(theme.border)
                    link(icon: "bell.badge.fill", tint: theme.warning, title: "Уведомления",
                         subtitle: "Push, операции, безопасность") { NotificationsSettingsView() }
                }

                section {
                    link(icon: "paintpalette.fill", tint: theme.accent, title: "Тема",
                         value: settings.themePreference.label) { ThemeSettingsView() }
                    Divider().overlay(theme.border)
                    link(icon: "globe", tint: theme.accent, title: "Язык",
                         value: settings.language.label) { LanguageSettingsView() }
                }

                section {
                    link(icon: "star.circle.fill", tint: theme.accent, title: "Подписка",
                         subtitle: "Тариф и привилегии") { SubscriptionView() }
                }

                Text("Настройки сохраняются на устройстве. Тема меняет оформление всего приложения.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Spacing.xs)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
    }

    private func section<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        SurfaceCard(padding: Spacing.sm) { VStack(spacing: 0) { content() } }
    }

    private func link<Destination: View>(icon: String, tint: Color, title: String,
                                         subtitle: String? = nil, value: String? = nil,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            ListRow(icon: icon, iconTint: tint, title: title, subtitle: subtitle,
                    value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSession.mockAuthenticated())
        .environment(\.theme, .default)
        .environment(\.apiClient, MockAPIClient())
}
