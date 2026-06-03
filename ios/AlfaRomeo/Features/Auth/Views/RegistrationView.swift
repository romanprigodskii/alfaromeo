import SwiftUI

/// KYC registration stepper (§9.0/§10.1). All steps are mocked: OTP 1111, liveness auto-passes,
/// Госуслуги is an OAuth stub. On finish → ``AppSession/completeAuthentication`` → main shell.
struct RegistrationView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.apiClient) private var api
    @Environment(\.theme) private var theme
    @State private var model = RegistrationModel()

    private let bio = BiometricAuthenticator.available()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Шаг \(model.step.rawValue + 1) из \(RegistrationModel.Step.allCases.count) · \(model.step.title)")
                    .font(BrandFont.micro).tracking(1).foregroundStyle(theme.textSecondary)
                ProgressBar(value: model.progress)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    stepContent
                    if let error = model.error {
                        Text(error).font(BrandFont.caption).foregroundStyle(theme.danger)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
        .padding(Spacing.lg)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Регистрация")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.step != .phone {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.back() } label: { Image(systemName: "chevron.left") }
                }
            }
        }
        .animation(Motion.smooth, value: model.step)
    }

    @ViewBuilder private var stepContent: some View {
        switch model.step {
        case .phone:      phoneStep
        case .otp:        otpStep
        case .kyc:        kycStep
        case .liveness:   livenessStep
        case .consents:   consentsStep
        case .pin:        pinStep
        case .biometrics: biometricsStep
        }
    }

    // MARK: Steps

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Ваш телефон", subtitle: "Отправим SMS с кодом подтверждения.")
            field($model.phone, keyboard: .phonePad, mono: true)
            PrimaryButton(title: "Далее", icon: "arrow.right") { model.submitPhone() }
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Код из SMS", subtitle: "Для демо введите 1111.")
            CodeEntryView(code: $model.code, length: 4)
            PrimaryButton(title: "Подтвердить") { model.submitOTP() }
                .disabled(model.code.count != 4)
        }
    }

    private var kycStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Верификация (KYC)", subtitle: "Выберите способ подтверждения личности.")
            optionCard(icon: "doc.text.fill", title: "Паспорт + ИНН", subtitle: "Ввести вручную",
                       selected: model.kycPath == .passport) { model.chooseKyc(.passport) }
            optionCard(icon: "checkmark.seal.fill", title: "Госуслуги", subtitle: "OAuth-заглушка · авто-успех",
                       selected: model.kycPath == .gosuslugi) { model.chooseKyc(.gosuslugi) }
            if model.kycPath == .passport {
                field($model.passportNumber, placeholder: "Серия и номер паспорта", keyboard: .numberPad)
                field($model.innNumber, placeholder: "ИНН", keyboard: .numberPad)
                PrimaryButton(title: "Далее", icon: "arrow.right") { model.submitPassport() }
            }
        }
    }

    private var livenessStep: some View {
        VStack(spacing: Spacing.lg) {
            AuthHeader(title: "Селфи для проверки", subtitle: "Liveness-проверка (демо: авто-успех).")
            ZStack {
                Circle()
                    .stroke(model.livenessPassed ? theme.success : theme.border, lineWidth: 3)
                    .frame(width: 160, height: 160)
                Image(systemName: model.livenessPassed ? "checkmark" : "face.smiling")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(model.livenessPassed ? theme.success : theme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            if model.livenessRunning { StatusPill(status: .processing, text: "Проверка…") }
            else if model.livenessPassed { StatusPill(status: .success, text: "Проверка пройдена") }

            if model.livenessPassed {
                PrimaryButton(title: "Далее", icon: "arrow.right") { model.submitLiveness() }
            } else {
                PrimaryButton(title: model.livenessRunning ? "Проверка…" : "Начать проверку") {
                    Task { await model.runLiveness() }
                }
                .disabled(model.livenessRunning)
            }
        }
    }

    private var consentsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Согласия", subtitle: "Подтвердите перед продолжением.")
            ConsentRow(isOn: $model.consentData, text: "Согласие на обработку персональных данных")
            ConsentRow(isOn: $model.consentTerms, text: "Условия обслуживания и тарифы")
            ConsentRow(isOn: $model.consentKyc, text: "Согласие на проверку (KYC/AML)")
            PrimaryButton(title: "Принять и продолжить") { model.submitConsents() }
                .disabled(!model.allConsents)
        }
    }

    private var pinStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Придумайте PIN", subtitle: "4 цифры для входа и подтверждений.")
            fieldLabel("PIN")
            CodeEntryView(code: $model.pin, length: 4, secure: true)
            fieldLabel("Повторите PIN")
            CodeEntryView(code: $model.pinConfirm, length: 4, secure: true, autofocus: false)
            PrimaryButton(title: "Далее", icon: "arrow.right") { model.submitPIN() }
                .disabled(model.pin.count != 4 || model.pinConfirm.count != 4)
        }
    }

    private var biometricsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            AuthHeader(title: "Быстрый вход", subtitle: "Включите биометрию и passkey (опционально).")
            toggleCard(icon: bio.systemImage, title: bio.label, enabled: model.faceIDEnabled, action: "Включить") {
                Task { await model.enableFaceID() }
            }
            toggleCard(icon: "person.badge.key.fill", title: "Passkey", enabled: model.passkeyCreated, action: "Создать") {
                Task { await model.createPasskey() }
            }
            PrimaryButton(title: "Готово · войти", icon: "checkmark") {
                Task { await model.finish(api: api, session: session) }
            }
        }
    }

    // MARK: Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(BrandFont.micro).tracking(1.5).foregroundStyle(theme.textSecondary)
    }

    private func field(_ binding: Binding<String>, placeholder: String = "",
                       keyboard: UIKeyboardType = .default, mono: Bool = false) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(keyboard)
            .font(mono ? BrandFont.mono(17) : BrandFont.body())
            .foregroundStyle(theme.textPrimary)
            .padding(Spacing.md)
            .background(theme.elevated, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func optionCard(icon: String, title: String, subtitle: String,
                            selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.accent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Text(subtitle).font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? theme.accent : theme.textSecondary)
            }
            .padding(Spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func toggleCard(icon: String, title: String, enabled: Bool,
                            action: String, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(theme.accent)
                .frame(width: 36)
            Text(title).font(BrandFont.bodyM.weight(.medium)).foregroundStyle(theme.textPrimary)
            Spacer()
            if enabled {
                StatusPill(status: .success, text: "Включено")
            } else {
                Button(action, action: onTap)
                    .font(BrandFont.callout.weight(.medium))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(Spacing.md)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(theme.border, lineWidth: 1))
    }
}
