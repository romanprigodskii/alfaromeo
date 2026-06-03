import Foundation
import Observation

/// Создание платёжного линка / QR (§8.3): сумма → назначение → генерация (мок) → шаринг.
@MainActor
@Observable
final class CreateLinkModel {
    var kind: PaymentLink.Kind
    var amountText: String = ""
    var purpose: String = ""

    init(kind: PaymentLink.Kind) { self.kind = kind }

    /// Parsed ₽ amount (thin-space / comma tolerant, shared with the Crypto hub formatter).
    var amount: Double { CryptoFormat.parse(amountText) }
    var canGenerate: Bool { amount > 0 }

    /// Generate the link/QR through the shared store (simulation) and return it for navigation.
    func generate(store: AcquiringStore) -> PaymentLink? {
        guard canGenerate else { return nil }
        return store.createLink(amount: amount, purpose: purpose, kind: kind)
    }
}
