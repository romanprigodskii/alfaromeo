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
            VStack(alignment: .leading, spacing: Spacing.lg) {
                authSection
                limitsSection
                devicesSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Безопасность")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.bottom, 96, for: .scrollContent)
        .animation(.snappy, value: endedSessions)
    }

    // MARK: Аутентификация

    private var authSection: some View {
        section("Вход и подтверждение") {
            SurfaceCard(padding: Spacing.md) {
                VStack(spacing: Spacing.md) {
                    toggleRow(icon: bio.systemImage, title: bio == .none ? "Биометрия" : bio.label,
                              subtitle: "Вход и подтверждение операций", isOn: faceIDBinding)
                    Divider().overlay(theme.border)
                    toggleRow(icon: "lock.fill", title: "Код-пароль (PIN)",
                              subtitle: "Запасной способ входа", isOn: $settings.pinEnabled)
                    Divider().overlay(theme.border)
                    toggleRow(icon: "key.fill", title: "Passkeys",
                              subtitle: "Беспарольный вход по ключу устройства", isOn: $settings.passkeysEnabled)
                }
            }
            if biometricError {
                Text("Не удалось подтвердить \(bio.label). Биометрия не включена.")
                    .font(BrandFont.caption).foregroundStyle(theme.danger)
            }
        }
    }

    // MARK: Лимиты

    private var limitsSection: some View {
        section("Лимит на операцию") {
            SurfaceCard(padding: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Операции свыше лимита требуют подтверждения биометрией (§10.3).")
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowChips(values: settings.operationLimitPresets,
                              selected: settings.perOperationLimit,
                              label: { settings.operationLimitLabel($0) },
                              onSelect: { settings.perOperationLimit = $0 },
                              theme: theme)
                }
            }
        }
    }

    // MARK: Устройства и сессии

    private var devicesSection: some View {
        section("Устройства и сессии") {
            SurfaceCard(padding: Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(DeviceSession.demo.enumerated()), id: \.element.id) { index, device in
                        deviceRow(device)
                        if index < DeviceSession.demo.count - 1 { Divider().overlay(theme.border) }
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: DeviceSession) -> some View {
        let ended = endedSessions.contains(device.id)
        return HStack(spacing: Spacing.md) {
            Image(systemName: device.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(device.isCurrent ? theme.success : theme.textSecondary)
                .frame(width: 36, height: 36)
                .background((device.isCurrent ? theme.success : theme.textSecondary).opacity(0.14),
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                Text(ended ? "Сессия завершена" : device.detail)
                    .font(BrandFont.caption).foregroundStyle(ended ? theme.danger : theme.textSecondary)
            }
            Spacer(minLength: Spacing.sm)
            if device.isCurrent {
                Badge(kind: .text("Текущее"), tint: theme.success)
            } else if !ended {
                Button("Завершить") { endedSessions.insert(device.id) }
                    .font(BrandFont.caption.weight(.semibold))
                    .foregroundStyle(theme.danger)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.sm)
        .opacity(ended ? 0.5 : 1)
    }

    // MARK: Builders

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(BrandFont.micro).tracking(1.5).foregroundStyle(theme.textSecondary)
            content()
        }
    }
}

/// Selectable value chips (used for the operation-limit presets).
private struct FlowChips: View {
    let values: [Double]
    let selected: Double
    let label: (Double) -> String
    let onSelect: (Double) -> Void
    let theme: Theme

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 96), spacing: Spacing.sm)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.sm) {
            ForEach(values, id: \.self) { value in
                let isOn = value == selected
                Button { onSelect(value) } label: {
                    Text(label(value))
                        .font(BrandFont.callout.weight(.medium))
                        .foregroundStyle(isOn ? theme.onAccent : theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(isOn ? theme.accent : theme.elevated,
                                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .stroke(isOn ? .clear : theme.border, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

#Preview {
    NavigationStack { SecuritySettingsView() }
        .environment(\.theme, .default)
}
