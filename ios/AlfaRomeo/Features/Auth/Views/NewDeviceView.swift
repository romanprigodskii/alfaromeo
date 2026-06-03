import SwiftUI

/// New-device confirmation (§9.0/§10.1): approve from a trusted device + device binding (mock).
struct NewDeviceView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AuthHeader(title: "Новое устройство",
                           subtitle: "Подтвердите вход со старого устройства или по звонку (device binding).")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Label("Запрос отправлен на доверенное устройство", systemImage: "iphone")
                            .font(BrandFont.callout).foregroundStyle(theme.textPrimary)
                        Text("Код подтверждения: 24–19")
                            .font(BrandFont.mono(15)).foregroundStyle(theme.textSecondary)
                    }
                }

                if confirming { StatusPill(status: .processing, text: "Подтверждение…") }

                PrimaryButton(title: "Я подтвердил со старого устройства", icon: "checkmark.shield") {
                    Task { await confirm() }
                }
                .disabled(confirming)

                if let error { Text(error).font(BrandFont.caption).foregroundStyle(theme.danger) }
            }
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новое устройство")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func confirm() async {
        confirming = true
        error = nil
        try? await Task.sleep(for: .milliseconds(1200))
        do {
            let user = try await api.currentUser()
            let profiles = try await api.profiles()
            guard let personal = profiles.first(where: { $0.type == .personal }) ?? profiles.first else {
                error = "Профиль не найден."
                confirming = false
                return
            }
            session.completeAuthentication(user: user, profile: personal, profiles: profiles)
        } catch {
            self.error = "Ошибка: \(error.localizedDescription)"
        }
        confirming = false
    }
}
