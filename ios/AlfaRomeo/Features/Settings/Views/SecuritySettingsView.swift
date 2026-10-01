import SwiftUI

/// Безопасность (§9.8): биометрия/Face ID, PIN, passkeys, лимит операций, список устройств/сессий.
/// Toggles persist in ``SettingsStore``. Enabling biometric unlock runs a real ``BiometricAuthenticator``
/// prompt on devices that have biometry enrolled (on a bare simulator it just flips, nothing to confirm).
struct SecuritySettingsView: View {
    @Environment(\.theme) private var theme
    @State private var settings = SettingsStore.shared

    private let bio = BiometricAuthenticator.available()
    @State private var biometricError = false
    @State private var endedSessions: Set<String> = []

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { settings.faceIDUnlock },
            set: { enabled in
                guard enabled else { settings.faceIDUnlock = false; return }
                guard bio != .none else { settings.faceIDUnlock = true; return }  // nothing to confirm
                Task { @MainActor in
                    let ok = await BiometricAuthenticator.authenticate(reason: "Включить вход по \(bio.label)")
                    settings.faceIDUnlock = ok
                    biometricError = !ok
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                authSection
                limitsSection
                devicesSection
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Безопасность")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(Motion.snappy, value: endedSessions)
    }

    // MARK: Аутентификация

    private var authSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            GroupedSection("Вход и подтверждение") {
                SettingsToggleRow(icon: bio.systemImage, title: bio == .none ? "Биометрия" : bio.label,
                                  subtitle: "Вход и подтверждение операций", isOn: faceIDBinding)
                SettingsToggleRow(icon: "lock", title: "Код-пароль",
                                  subtitle: "Запасной способ входа", isOn: $settings.pinEnabled)
                SettingsToggleRow(icon: "key", title: "Passkeys",
                                  subtitle: "Вход по ключу устройства", isOn: $settings.passkeysEnabled)
            }
            if biometricError {
                Text("Не удалось подтвердить \(bio.label). Биометрия не включена.")
                    .font(BrandFont.footnote).foregroundStyle(theme.danger)
                    .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: Лимиты

    private var limitsSection: some View {
        GroupedSection("Лимит на операцию",
                       footer: "Операции свыше лимита нужно подтвердить биометрией.") {
            ForEach(settings.operationLimitPresets, id: \.self) { value in
                let isOn = value == settings.perOperationLimit
                Button { settings.perOperationLimit = value } label: {
                    HStack(spacing: Spacing.sm) {
                        ListRow(title: settings.operationLimitLabel(value))
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
    }

    // MARK: Устройства и сессии

    private var devicesSection: some View {
        GroupedSection("Устройства") {
            ForEach(DeviceSession.demo) { device in deviceRow(device) }
        }
    }

    private func deviceRow(_ device: DeviceSession) -> some View {
        let ended = endedSessions.contains(device.id)
        return HStack(spacing: ListRow.glyphSpacing) {
            GlyphCircle(systemImage: device.icon, size: ListRow.glyphSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                Text(ended ? "Сессия завершена" : device.detail)
                    .font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if device.isCurrent {
                Badge(kind: .text("Это устройство"), tint: theme.success)
            } else if !ended {
                Button("Завершить") { endedSessions.insert(device.id) }
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.danger)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.rowMinHeightTwoLine)
        .opacity(ended ? 0.5 : 1)
        .groupedRowTextInset(ListRow.glyphSize + ListRow.glyphSpacing)
    }
}

#Preview {
    NavigationStack { SecuritySettingsView() }
        .environment(\.theme, .default)
}
