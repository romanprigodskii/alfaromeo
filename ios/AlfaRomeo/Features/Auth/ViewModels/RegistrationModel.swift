import Foundation
import Observation

/// State machine for the KYC registration stepper (§9.0/§10.1):
/// телефон → OTP → KYC (паспорт+ИНН / Госуслуги) → liveness → согласия → PIN → биометрия.
@MainActor
@Observable
final class RegistrationModel {
    enum Step: Int, CaseIterable {
        case phone, otp, kyc, liveness, consents, pin, biometrics

        var title: String {
            switch self {
            case .phone:      return "Телефон"
            case .otp:        return "Код из SMS"
            case .kyc:        return "Верификация"
            case .liveness:   return "Селфи"
            case .consents:   return "Согласия"
            case .pin:        return "PIN-код"
            case .biometrics: return "Безопасность"
            }
        }
    }

    enum KycPath: String { case passport, gosuslugi }

    var step: Step = .phone
    var error: String?

    var phone = "+7 999 000-00-00"
    var code = ""
    var kycPath: KycPath?
    var passportNumber = ""
    var innNumber = ""
    var livenessRunning = false
    var livenessPassed = false
    var consentData = false
    var consentTerms = false
    var consentKyc = false
    var pin = ""
    var pinConfirm = ""
    var faceIDEnabled = false
    var passkeyCreated = false

    private let passkeys = PasskeyService()

    var progress: Double { Double(step.rawValue + 1) / Double(Step.allCases.count) }
    var allConsents: Bool { consentData && consentTerms && consentKyc }

    func back() {
        error = nil
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    private func advance() {
        error = nil
        if let next = Step(rawValue: step.rawValue + 1) { step = next }
    }

    func submitPhone() {
        guard phone.filter(\.isNumber).count >= 10 else { error = "Введите номер телефона."; return }
        code = ""
        advance()
    }

    func submitOTP() {
        guard code == "1111" else { error = "Неверный код (для демо: 1111)."; code = ""; return }
        advance()
    }

    func chooseKyc(_ path: KycPath) {
        error = nil
        kycPath = path
        if path == .gosuslugi { advance() } // Госуслуги OAuth-заглушка → авто-успех
    }

    func submitPassport() {
        guard !passportNumber.isEmpty, !innNumber.isEmpty else { error = "Заполните паспорт и ИНН."; return }
        advance()
    }

    func runLiveness() async {
        livenessRunning = true
        livenessPassed = false
        try? await Task.sleep(for: .milliseconds(1600))
        livenessRunning = false
        livenessPassed = true // mock: liveness авто-проходит
    }

    func submitLiveness() {
        guard livenessPassed else { error = "Пройдите проверку селфи."; return }
        advance()
    }

    func submitConsents() {
        guard allConsents else { error = "Подтвердите все согласия."; return }
        advance()
    }

    func submitPIN() {
        guard pin.count == 4 else { error = "PIN должен состоять из 4 цифр."; return }
        guard pin == pinConfirm else { error = "PIN-коды не совпадают."; pinConfirm = ""; return }
        advance()
    }

    func enableFaceID() async {
        faceIDEnabled = await BiometricAuthenticator.authenticate(reason: "Включить вход по Face ID")
        if !faceIDEnabled { error = "Биометрия недоступна. Включить можно позже в настройках." }
    }

    func createPasskey() async {
        passkeyCreated = await passkeys.register(userName: phone)
        if !passkeyCreated { error = "Passkey недоступен в демо. Добавить можно позже." }
    }

    func finish(api: any APIClient, session: AppSession) async {
        do {
            // Bind the identity to the typed phone: persona (name/cards/business) is deterministic, and
            // ₽ + crypto balances come live from the backend wallet (``WalletService``).
            MockData.select(forPhone: phone)
            let normalized = MockData.normalizePhone(phone)
            UserDefaults.standard.set(normalized, forKey: "ar_user_phone")

            let auth = try await api.signIn(phone: phone, code: code)
            let profiles = try await api.profiles()
            guard let personal = profiles.first(where: { $0.type == .personal }) ?? profiles.first else {
                error = "Профиль не найден."
                return
            }
            await WalletService.shared.register(phone: normalized, displayName: MockData.activePersona.personName)
            session.demoPIN = pin
            session.completeAuthentication(user: auth.user, profile: personal, profiles: profiles)
        } catch {
            self.error = "Ошибка: \(error.localizedDescription)"
        }
    }
}
