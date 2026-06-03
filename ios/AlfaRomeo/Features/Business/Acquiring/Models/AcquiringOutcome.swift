import Foundation

/// Почему приём оплаты не состоялся (§8.3) — пока единственная причина в демо: отказ биометрии.
enum AcquiringDecline: Hashable, Sendable {
    case canceled

    var title: String {
        switch self { case .canceled: return "Оплата не принята" }
    }
    var message: String {
        switch self { case .canceled: return "Подтверждение не пройдено. Средства не зачислены." }
    }
    var systemImage: String {
        switch self { case .canceled: return "xmark" }
    }
}

/// Состояние приёма оплаты — драйвит анимированный статус (§8.3), как ``CryptoOutcome`` в крипто-хабе.
enum AcquiringOutcome: Hashable, Sendable {
    case processing
    case settled(AcquiringReceipt)
    case declined(AcquiringDecline)

    var isProcessing: Bool { if case .processing = self { return true }; return false }
}
