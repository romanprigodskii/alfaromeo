import SwiftUI

/// Язык (§9.8): stub picker. The choice persists in ``SettingsStore``; full localization is a later
/// phase, so the interface stays Russian for now (stated honestly).
struct LanguageSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            GroupedSection(footer: "Пока интерфейс только на русском. Перевод появится в следующем обновлении.") {
                ForEach(AppLanguage.allCases) { lang in row(lang) }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Язык")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ lang: AppLanguage) -> some View {
        let isOn = settings.language == lang
        return Button {
            withAnimation(Motion.snappy) { settings.language = lang }
        } label: {
            HStack(spacing: Spacing.sm) {
                ListRow(title: lang.label)
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
    NavigationStack { LanguageSettingsView() }
        .environment(\.theme, .default)
}
