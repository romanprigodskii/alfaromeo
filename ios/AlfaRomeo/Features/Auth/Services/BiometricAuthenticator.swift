import Foundation
import LocalAuthentication

/// Thin wrapper over LocalAuthentication — presents the real Face ID / Touch ID prompt (§10.1).
enum BiometricAuthenticator {
    enum Kind {
        case faceID, touchID, opticID, none

        var label: String {
            switch self {
            case .faceID:  return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none:    return "Биометрия"
            }
        }

        var systemImage: String {
            switch self {
            case .faceID, .opticID: return "faceid"
            case .touchID:          return "touchid"
            case .none:             return "lock.shield"
            }
        }
    }

    /// The device's available biometry (for labelling the button).
    static func available() -> Kind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default:       return .none
        }
    }

    /// Presents the system biometric prompt (with device-passcode fallback). Returns true on success;
    /// the caller offers PIN/OTP on false (§10.1: отказ биометрии → PIN).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Ввести код устройства"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            #if targetEnvironment(simulator)
            // The simulator has no enrolled biometrics, so the prompt is unavailable. In a sim build
            // treat that as success so the demo's transfers complete (real device → real Face ID).
            return true
            #else
            return false
            #endif
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
