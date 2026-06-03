import SwiftUI

/// Тема (§9.8) — Система / Светлая / Тёмная. Writing the choice into ``SettingsStore`` re-themes the
/// whole app live (read at ``RootView``). The dark palette already exists in ``Theme``; this is the
/// access to it. Does not affect the scoped dark «проф-режим» of crypto trading (that forces its own
/// scheme locally).
struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard(padding: Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(ThemePreference.allCases.enumerated()), id: \.element.id) { index, pref in
                            row(pref)
                            if index < ThemePreference.allCases.count - 1 { Divider().overlay(theme.border) }
                        }
                    }
                }
                Text("«Система» следует оформлению устройства. Светлая — основная схема банка; тёмная доступна целиком.")
                    .font(BrandFont.micro).foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Тема")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ pref: ThemePreference) -> some View {
        let isOn = settings.themePreference == pref
        return Button {
            withAnimation(.snappy) { settings.themePreference = pref }
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: pref.icon)
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Text(pref.label).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
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
    NavigationStack { ThemeSettingsView() }
        .environment(\.theme, .default)
}
