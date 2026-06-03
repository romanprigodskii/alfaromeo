import Observation

/// Drives the login screen: phone+OTP (mock code 1111) with failure backoff, biometrics, passkey,
/// and a PIN fallback. On success it loads the user/profiles via ``APIClient`` and authenticates.
@MainActor
@Observable
final class LoginViewModel {
    var phone: String = "+7 999 000-00-00"
    var code: String = ""
    var pin: String = ""
    var codeSent = false
    var showPINEntry = false
    var error: String?
    var isLoading = false

    // OTP backoff (§10.1: backoff OTP, блок после N)
    var failedAttempts = 0
    var cooldownRemaining = 0
    private var cooldownTask: Task<Void, Never>?

    let biometry = BiometricAuthenticator.available()
    private let passkeys = PasskeyService()

    var canSubmitOTP: Bool { code.count == 4 && cooldownRemaining == 0 && !isLoading }
    private var isLockedOut: Bool { failedAttempts >= 5 }

    func sendCode() {
        error = nil
        code = ""
        codeSent = true
    }

    func submitOTP(api: any APIClient, session: AppSession) async {
        guard cooldownRemaining == 0 else { return }
        error = nil
        guard code == "1111" else {
            failedAttempts += 1
            code = ""
            if isLockedOut {
                error = "Слишком много попыток. Вход временно заблокирован."
                startCooldown(60)
            } else {
                error = "Неверный код. Осталось попыток: \(5 - failedAttempts)."
                startCooldown(failedAttempts * 5)
            }
            return
        }
        await finishLogin(api: api, session: session)
    }

    func loginWithBiometrics(api: any APIClient, session: AppSession) async {
        error = nil
        if await BiometricAuthenticator.authenticate(reason: "Вход в Альфа-Ромео") {
            await finishLogin(api: api, session: session)
        } else {
            error = "\(biometry.label): не удалось. Используйте код или PIN."
        }
    }

    func loginWithPasskey(api: any APIClient, session: AppSession) async {
        error = nil
        if await passkeys.signIn() {
            await finishLogin(api: api, session: session)
        } else {
            error = "Passkey недоступен в демо-окружении. Используйте Face ID или код."
        }
    }

    func submitPIN(api: any APIClient, session: AppSession) async {
        error = nil
        guard pin == (session.demoPIN ?? "0000") else {
            error = "Неверный PIN."
            pin = ""
            return
        }
        await finishLogin(api: api, session: session)
    }

    private func finishLogin(api: any APIClient, session: AppSession) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await api.currentUser()
            let profiles = try await api.profiles()
            guard let personal = profiles.first(where: { $0.type == .personal }) ?? profiles.first else {
                error = "Профиль не найден."
                return
            }
            session.completeAuthentication(user: user, profile: personal, profiles: profiles)
        } catch {
            self.error = "Ошибка входа: \(error.localizedDescription)"
        }
    }

    /// Reveal the PIN entry, clearing stale OTP input / error so the two methods don't bleed state.
    func showPIN() {
        error = nil
        code = ""
        showPINEntry = true
    }

    private func startCooldown(_ seconds: Int) {
        cooldownRemaining = seconds
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor in
            while cooldownRemaining > 0 {
                do { try await Task.sleep(for: .seconds(1)) } catch { break } // cancelled → stop
                if Task.isCancelled { break }
                cooldownRemaining = max(0, cooldownRemaining - 1)
            }
        }
    }
}
