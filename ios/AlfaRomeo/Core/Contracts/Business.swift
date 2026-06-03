import Foundation

// Mirror of /shared (Business set, §11.3, §8) — minimal slice. Keep in sync until codegen.

enum LegalForm: String, Codable, CaseIterable, Sendable {
    case ip
    case ooo
    case selfEmployed = "self_employed"
}

/// A legal entity behind a business profile.
struct Business: Codable, Identifiable, Hashable, Sendable {
    let profileId: String
    let legalForm: LegalForm
    let ogrn: String
    let inn: String
    let name: String

    var id: String { profileId }
}

/// A counterparty in the business address book.
struct Counterparty: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let businessId: String
    let inn: String
    let name: String
    var account: String?
}

enum InvoiceStatus: String, Codable, CaseIterable, Sendable {
    case draft, sent, paid, overdue, canceled
}

/// An issued/received invoice.
struct Invoice: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let businessId: String
    var counterpartyId: String?
    let amount: Double
    let status: InvoiceStatus
    var due: String?
}

enum PayrollStatus: String, Codable, CaseIterable, Sendable {
    case draft, processing, completed, failed
}

/// A payroll run (items collapsed to a count + total for the mock).
struct PayrollRun: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let businessId: String
    let status: PayrollStatus
    let itemsCount: Int
    let totalAmount: Double
}

enum AcquiringType: String, Codable, CaseIterable, Sendable {
    case online, terminal, qr, link, crypto
}

/// An acquiring point (online / QR / terminal / crypto, §8.2).
struct AcquiringPoint: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let businessId: String
    let type: AcquiringType
    var label: String?
}

enum ApprovalStatus: String, Codable, CaseIterable, Sendable {
    case pending, signed, rejected
}

/// A multi-step (2-of-N) approval request for a business operation (§8.2/§11.8).
struct ApprovalRequest: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let businessId: String
    let opId: String
    let required: Int
    let signedBy: [String]
    let status: ApprovalStatus
}
