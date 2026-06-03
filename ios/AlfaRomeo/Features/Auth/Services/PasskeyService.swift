import Foundation
import AuthenticationServices
import UIKit

/// Wrapper over AuthenticationServices passkeys (§9.0/§10.1). In a demo simulator without an
/// associated-domains entitlement the system call fails — callers treat `false` as a graceful
/// fallback ("аккуратный фолбэк/стаб") and continue with Face ID / OTP / PIN.
@MainActor
final class PasskeyService: NSObject {
    private let relyingParty = "alfa-romeo.bank"
    private var continuation: CheckedContinuation<Bool, Never>?
    private var watchdog: Task<Void, Never>?

    /// Attempt to register a passkey. Returns true on success, false on cancel/unavailable.
    func register(userName: String) async -> Bool {
        await withCheckedContinuation { cont in
            guard continuation == nil else { cont.resume(returning: false); return } // re-entrancy guard
            continuation = cont
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
            let request = provider.createCredentialRegistrationRequest(
                challenge: Self.randomData(32),
                name: userName,
                userID: Data(userName.utf8)
            )
            perform(request)
        }
    }

    /// Attempt a passkey assertion (login). Returns true on success, false on cancel/unavailable.
    func signIn() async -> Bool {
        await withCheckedContinuation { cont in
            guard continuation == nil else { cont.resume(returning: false); return } // re-entrancy guard
            continuation = cont
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingParty)
            let request = provider.createCredentialAssertionRequest(challenge: Self.randomData(32))
            perform(request)
        }
    }

    private func perform(_ request: ASAuthorizationRequest) {
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        // Watchdog bound to THIS request: if no delegate callback ever fires (misconfigured demo
        // env), resolve to false rather than hanging. Cancelled in finish() so it can never resolve
        // a later call's continuation.
        watchdog?.cancel()
        watchdog = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled { finish(false) }
        }
    }

    private func finish(_ value: Bool) {
        watchdog?.cancel()
        watchdog = nil
        // Snapshot + nil before resuming, so a second callback (or the watchdog) is a no-op.
        let cont = continuation
        continuation = nil
        cont?.resume(returning: value)
    }

    private static func randomData(_ count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }
}

extension PasskeyService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(true)
    }
    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithError error: Error) {
        finish(false)
    }
}

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
