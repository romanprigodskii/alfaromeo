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
                Text("Подтвердите вход на доверенном устройстве или по звонку.")
                    .font(BrandFont.bodyM)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GroupedSection {
                    ListRow(icon: "iphone", title: "Запрос отправлен",
                            subtitle: "На доверенное устройство")
                    ListRow(icon: "number", title: "Код подтверждения", value: "24–19")
                }

                if confirming { StatusPill(status: .processing, text: "Подтверждение…") }

                PrimaryButton(title: "Я подтвердил на старом устройстве") {
                    Task { await confirm() }
                }
                .disabled(confirming)

                if let error { Text(error).font(BrandFont.footnote).foregroundStyle(theme.danger) }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Новое устройство")
        .navigationBarTitleDisplayMode(.large)
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
