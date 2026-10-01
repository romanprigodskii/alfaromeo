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
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    fieldLabel("Телефон")
                    phoneField
                }

                if model.codeSent {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        fieldLabel("Код из SMS, демо: 1111")
                        CodeEntryView(code: $model.code, length: 4)
                        if model.cooldownRemaining > 0 {
                            Text("Повторить через \(model.cooldownRemaining) с")
                                .font(BrandFont.footnote)
                                .foregroundStyle(theme.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    PrimaryButton(title: "Войти") {
                        Task { await model.submitOTP(api: api, session: session) }
                    }
                    .disabled(!model.canSubmitOTP)
                } else {
                    PrimaryButton(title: "Получить код") { model.sendCode() }
                }

                if let error = model.error {
                    Text(error).font(BrandFont.footnote).foregroundStyle(theme.danger)
                }

                if model.showPINEntry {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        fieldLabel("PIN-код, демо: 0000")
                        CodeEntryView(code: $model.pin, length: 4, secure: true, autofocus: false)
                    }
                    pinSubmitButton
                        .disabled(model.pin.count != 4)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    fieldLabel("Другие способы входа")
                    GroupedSection {
                        methodRow(icon: model.biometry.systemImage, title: model.biometry.label) {
                            Task { await model.loginWithBiometrics(api: api, session: session) }
                        }
                        methodRow(icon: "person.badge.key", title: "Passkey") {
                            Task { await model.loginWithPasskey(api: api, session: session) }
                        }
                        if !model.showPINEntry {
                            methodRow(icon: "circle.grid.3x3", title: "PIN-код") { model.showPIN() }
                        }
                        methodRow(icon: "iphone", title: "Вход с нового устройства") {
                            coordinator.push(.newDevice)
                        }
                    }
                }

                HStack(spacing: Spacing.xs) {
                    Text("Нет аккаунта?")
                        .foregroundStyle(theme.textSecondary)
                    Button("Создать") { coordinator.push(.register) }
                        .fontWeight(.medium)
                        .foregroundStyle(theme.accent)
                }
                .font(BrandFont.body(15))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Вход")
        .navigationBarTitleDisplayMode(.large)
        .overlay { if model.isLoading { loadingOverlay } }
    }

    /// One primary per screen: once the SMS code is on screen, its «Войти» is the primary action.
    @ViewBuilder private var pinSubmitButton: some View {
        if model.codeSent {
            SecondaryButton(title: "Подтвердить PIN-код") { submitPIN() }
        } else {
            PrimaryButton(title: "Подтвердить PIN-код") { submitPIN() }
        }
    }

    private func submitPIN() {
        Task { await model.submitPIN(api: api, session: session) }
    }

    private var phoneField: some View {
        TextField("", text: $model.phone)
            .keyboardType(.phonePad)
            .font(BrandFont.mono(17))
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Spacing.rowMinHeight)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
    }

    private func methodRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ListRow(icon: icon, title: title, showsChevron: true)
        }
        .buttonStyle(.row)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView().controlSize(.large).tint(.white)
        }
    }
}
