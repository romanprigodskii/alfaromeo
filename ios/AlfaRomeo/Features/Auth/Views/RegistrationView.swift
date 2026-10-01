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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Шаг \(model.step.rawValue + 1) из \(RegistrationModel.Step.allCases.count)")
                    .font(BrandFont.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .monospacedDigit()
                ProgressBar(value: model.progress)
            }
            .padding(.horizontal, Spacing.screen)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    stepContent
                    if let error = model.error {
                        Text(error).font(BrandFont.footnote).foregroundStyle(theme.danger)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.lg)
            }
        }
        .padding(.top, Spacing.sm)
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
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "Телефон", subtitle: "Пришлём SMS с кодом подтверждения.")
            field($model.phone, keyboard: .phonePad, mono: true)
            PrimaryButton(title: "Далее") { model.submitPhone() }
        }
    }

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "Код из SMS", subtitle: "Отправили на \(model.phone). Демо-код: 1111.")
            CodeEntryView(code: $model.code, length: 4)
            PrimaryButton(title: "Подтвердить") { model.submitOTP() }
                .disabled(model.code.count != 4)
        }
    }

    private var kycStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "Проверка личности", subtitle: "Выберите способ.")
            GroupedSection {
                optionRow(icon: "doc.text", title: "Паспорт и ИНН", subtitle: "Ввести вручную",
                          selected: model.kycPath == .passport) { model.chooseKyc(.passport) }
                optionRow(icon: "checkmark.seal", title: "Госуслуги", subtitle: "Демо: подтверждается автоматически",
                          selected: model.kycPath == .gosuslugi) { model.chooseKyc(.gosuslugi) }
            }
            if model.kycPath == .passport {
                GroupedSection {
                    inputRow($model.passportNumber, placeholder: "Серия и номер паспорта")
                    inputRow($model.innNumber, placeholder: "ИНН")
                }
                PrimaryButton(title: "Далее") { model.submitPassport() }
            }
        }
    }

    private var livenessStep: some View {
        VStack(spacing: Spacing.lg) {
            AuthHeader(title: "Селфи", subtitle: "Проверка, что перед камерой вы. В демо проходит автоматически.")
            ZStack {
                Circle()
                    .fill(theme.surface)
                Circle()
                    .stroke(model.livenessPassed ? theme.success : theme.border, lineWidth: 2)
                Image(systemName: model.livenessPassed ? "checkmark" : "face.smiling")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(model.livenessPassed ? theme.success : theme.textSecondary)
            }
            .frame(width: 160, height: 160)
            .frame(maxWidth: .infinity)

            if model.livenessRunning { StatusPill(status: .processing, text: "Проверка…") }
            else if model.livenessPassed { StatusPill(status: .success, text: "Проверка пройдена") }

            if model.livenessPassed {
                PrimaryButton(title: "Далее") { model.submitLiveness() }
            } else {
                PrimaryButton(title: model.livenessRunning ? "Проверка…" : "Начать проверку") {
                    Task { await model.runLiveness() }
                }
                .disabled(model.livenessRunning)
            }
        }
    }

    private var consentsStep: some View {
        let accepted = [model.consentData, model.consentTerms, model.consentKyc].filter { $0 }.count
        return VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "Согласия", subtitle: "Отмечено \(accepted) из 3")
            GroupedSection {
                ConsentRow(isOn: $model.consentData, text: "Обработка персональных данных")
                ConsentRow(isOn: $model.consentTerms, text: "Условия обслуживания и тарифы")
                ConsentRow(isOn: $model.consentKyc, text: "Проверка личности (KYC/AML)")
            }
            PrimaryButton(title: "Принять и продолжить") { model.submitConsents() }
                .disabled(!model.allConsents)
        }
    }

    private var pinStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "PIN-код", subtitle: "4 цифры для входа и подтверждения операций.")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                fieldLabel("PIN-код")
                CodeEntryView(code: $model.pin, length: 4, secure: true)
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                fieldLabel("Повторите PIN-код")
                CodeEntryView(code: $model.pinConfirm, length: 4, secure: true, autofocus: false)
            }
            PrimaryButton(title: "Далее") { model.submitPIN() }
                .disabled(model.pin.count != 4 || model.pinConfirm.count != 4)
        }
    }

    private var biometricsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            AuthHeader(title: "Быстрый вход", subtitle: "Необязательно. Включить можно позже в настройках.")
            GroupedSection {
                toggleRow(icon: bio.systemImage, title: bio.label, enabled: model.faceIDEnabled, action: "Включить") {
                    Task { await model.enableFaceID() }
                }
                toggleRow(icon: "person.badge.key", title: "Passkey", enabled: model.passkeyCreated, action: "Создать") {
                    Task { await model.createPasskey() }
                }
            }
            PrimaryButton(title: "Завершить и войти") {
                Task { await model.finish(api: api, session: session) }
            }
        }
    }

    // MARK: Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
    }

    private func field(_ binding: Binding<String>, placeholder: String = "",
                       keyboard: UIKeyboardType = .default, mono: Bool = false) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(keyboard)
            .font(mono ? BrandFont.mono(17) : BrandFont.bodyM)
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: Spacing.rowMinHeight)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    /// A text input as a row of a ``GroupedSection`` (the section supplies the side padding).
    private func inputRow(_ binding: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(.numberPad)
            .font(BrandFont.bodyM.monospacedDigit())
            .foregroundStyle(theme.textPrimary)
            .frame(minHeight: Spacing.rowMinHeight)
    }

    private func optionRow(icon: String, title: String, subtitle: String,
                           selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GlyphCircle(systemImage: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
                    Text(subtitle).font(BrandFont.subheadline).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? theme.accent : theme.textTertiary)
            }
            .padding(.vertical, Spacing.rowVertical)
            .frame(minHeight: Spacing.rowMinHeightTwoLine)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .groupedRowTextInset(48)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func toggleRow(icon: String, title: String, enabled: Bool,
                           action: String, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            GlyphCircle(systemImage: icon)
            Text(title).font(BrandFont.bodyM).foregroundStyle(theme.textPrimary)
            Spacer(minLength: Spacing.sm)
            if enabled {
                StatusPill(status: .success, text: "Включено")
            } else {
                Button(action, action: onTap)
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.vertical, Spacing.rowVertical)
        .frame(minHeight: Spacing.rowMinHeight)
        .groupedRowTextInset(48)
    }
}
