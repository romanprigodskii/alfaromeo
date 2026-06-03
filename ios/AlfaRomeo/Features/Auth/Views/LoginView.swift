import SwiftUI

/// Login (§9.0): phone + OTP (demo 1111) with backoff, Face ID, passkey, and PIN fallback.
struct LoginView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(AuthCoordinator.self) private var coordinator
    @Environment(\.theme) private var theme
    @State private var model = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                AuthHeader(title: "С возвращением", subtitle: "Войдите в Альфа-Ромео")

                fieldLabel("Телефон")
                phoneField

                if model.codeSent {
                    fieldLabel("Код из SMS (демо: 1111)")
                    CodeEntryView(code: $model.code, length: 4)
                    if model.cooldownRemaining > 0 {
                        Text("Повторить через \(model.cooldownRemaining) с")
                            .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    PrimaryButton(title: "Войти") {
                        Task { await model.submitOTP(api: api, session: session) }
                    }
                    .disabled(!model.canSubmitOTP)
                } else {
                    PrimaryButton(title: "Получить код", icon: "envelope") { model.sendCode() }
                }

                if let error = model.error {
                    Text(error).font(BrandFont.caption).foregroundStyle(theme.danger)
                }

                if model.showPINEntry {
                    fieldLabel("PIN (демо: 0000)")
                    CodeEntryView(code: $model.pin, length: 4, secure: true, autofocus: false)
                    PrimaryButton(title: "Подтвердить PIN") {
                        Task { await model.submitPIN(api: api, session: session) }
                    }
                    .disabled(model.pin.count != 4)
                }

                dividerOr

                HStack(spacing: Spacing.md) {
                    iconButton(icon: model.biometry.systemImage, label: model.biometry.label) {
                        Task { await model.loginWithBiometrics(api: api, session: session) }
                    }
                    iconButton(icon: "person.badge.key.fill", label: "Passkey") {
                        Task { await model.loginWithPasskey(api: api, session: session) }
                    }
                }

                if !model.showPINEntry {
                    Button("Войти по PIN-коду") { model.showPIN() }
                        .font(BrandFont.callout).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                Divider().overlay(theme.border).padding(.vertical, Spacing.xs)

                VStack(spacing: Spacing.sm) {
                    Button("Нет аккаунта? Создать") { coordinator.push(.register) }
                        .font(BrandFont.callout.weight(.medium)).foregroundStyle(theme.accent)
                    Button("Вход с нового устройства") { coordinator.push(.newDevice) }
                        .font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if model.isLoading { loadingOverlay } }
    }

    private var phoneField: some View {
        TextField("", text: $model.phone)
            .keyboardType(.phonePad)
            .font(BrandFont.mono(17))
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(BrandFont.micro).tracking(1.5).foregroundStyle(theme.textSecondary)
    }

    private var dividerOr: some View {
        HStack(spacing: Spacing.md) {
            line
            Text("или").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
            line
        }
    }
    private var line: some View { Rectangle().fill(theme.border).frame(height: 1) }

    private func iconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(theme.accent)
                Text(label).font(BrandFont.caption).foregroundStyle(theme.textPrimary)
            }
            .frame(maxWidth: .infinity).frame(height: 84)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}
