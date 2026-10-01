import Foundation
import Observation

/// Автоплатежи (§9.2) with their on/off state kept across launches. The list itself is the demo
/// fixture; only the user's toggles are persisted, as an id → isOn map in `UserDefaults`.
@MainActor
@Observable
final class AutopaymentsStore {
    static let shared = AutopaymentsStore()

    private(set) var items: [Autopayment]

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "payments.autopayments.isOn"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.key) as? [String: Bool] ?? [:]
        items = PaymentsMockData.autopayments.map { auto in
            var auto = auto
            if let isOn = saved[auto.id] { auto.isOn = isOn }
            return auto
        }
    }

    func setOn(_ isOn: Bool, id: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isOn = isOn
        defaults.set(Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.isOn) }), forKey: Self.key)
    }
}
