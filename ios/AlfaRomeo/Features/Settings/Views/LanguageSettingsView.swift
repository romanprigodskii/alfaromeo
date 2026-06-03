import SwiftUI

/// Язык (§9.8) — stub picker. The choice persists in ``SettingsStore``; full localization is a later
/// phase, so the interface stays Russian for now (stated honestly).
struct LanguageSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, lang in
                            row(lang)
                            if index < AppLanguage.allCases.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
                Text("Локализация интерфейса появится в следующем обновлении — сейчас приложение на русском (демо).")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Язык")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ lang: AppLanguage) -> some View {
        let isOn = settings.language == lang
        return Button {
            withAnimation(.snappy) { settings.language = lang }
        } label: {
            HStack(spacing: Spacing.md) {
                Text(lang.nativeFlag).font(.system(size: 24))
                    .frame(width: 36, height: 36)
                Text(lang.label).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { LanguageSettingsView() }
        .environment(\.theme, .default)
}
