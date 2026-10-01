import SwiftUI

/// Тема (§9.8): Система / Светлая / Тёмная. Writing the choice into ``SettingsStore`` re-themes the
/// whole app live (read at ``RootView``). The dark palette already exists in ``Theme``; this is the
/// access to it.
struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            GroupedSection(footer: "«Система» повторяет оформление устройства. Основная схема банка светлая.") {
                ForEach(ThemePreference.allCases) { pref in row(pref) }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Тема")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ pref: ThemePreference) -> some View {
        let isOn = settings.themePreference == pref
        return Button {
            withAnimation(Motion.snappy) { settings.themePreference = pref }
        } label: {
            HStack(spacing: Spacing.sm) {
                ListRow(icon: pref.icon, title: pref.label)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { ThemeSettingsView() }
        .environment(\.theme, .default)
}
