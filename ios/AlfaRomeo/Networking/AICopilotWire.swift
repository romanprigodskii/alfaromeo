import Foundation

/// Wire contract for the AI copilot (§11.7) — the iOS mirror of `backend/src/modules/ai/ai.types.ts`.
/// `POST /ai/chat` streams `event: token|toolDraft|done`; `POST /ai/confirm-action` echoes a draft back
/// (verbatim) for the server to re-verify + simulate. These types live in the Networking layer because
/// they describe the transport; the Copilot feature builds its UI models on top of them.

// MARK: - JSON value (lossless)

/// A lossless JSON value tree. Integers decode as `.int` (not `.double`), so re-encoding reproduces the
/// EXACT numeric form the server signed — essential for the action-draft HMAC round-trip: `confirm-action`
/// re-derives the signature from the echoed draft's field VALUES (`ai.guardrails.ts`), so `5000` must not
/// become `5000.0` when we send the draft back.
enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {            // bool BEFORE int (JSON `true` ≠ 1)
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {             // int BEFORE double (keeps 5000 → 5000)
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i):    try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b):   try c.encode(b)
        case .null:          try c.encodeNil()
        case .object(let o): try c.encode(o)
        case .array(let a):  try c.encode(a)
        }
    }

    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    var doubleValue: Double? {
        switch self {
        case .int(let i):    return Double(i)
        case .double(let d): return d
        default:             return nil
        }
    }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
    subscript(_ key: String) -> JSONValue? { objectValue?[key] }

    /// A JSON number that stays an integer when whole — matches JS `JSON.stringify` so signatures verify.
    static func number(_ value: Double) -> JSONValue {
        (value.rounded() == value && abs(value) < 9.007e15) ? .int(Int(value)) : .double(value)
    }
}

// MARK: - Request / message

/// One conversation turn sent to `POST /ai/chat`. Only `user` / `assistant`; the system prompt is
/// built server-side.
struct AIChatMessage: Codable, Hashable, Sendable {
    let role: String      // "user" | "assistant"
    let content: String
}

/// `POST /ai/chat` body.
struct AIChatRequest: Encodable, Sendable {
    let profileId: String
    let mode: String       // "support" | "coach" | "agent"
    let messages: [AIChatMessage]
}

// MARK: - Tool draft

/// A proposed-but-unexecuted financial action (§11.7). Kept with its full raw JSON (`raw`) so it can be
/// echoed byte-faithfully to `POST /ai/confirm-action`; the typed fields drive the confirm card.
struct AIToolDraft: Hashable, Sendable, Identifiable {
    /// The whole draft object exactly as received — re-sent verbatim so the HMAC re-verifies.
    let raw: JSONValue
    let draftId: String
    let tool: String          // make_transfer | open_deposit | freeze_card
    let summary: String
    let amount: Double?
    let currency: String?
    let blocked: Bool
    let blockReason: String?
    let params: [String: JSONValue]
    let expiresAt: String?

    var id: String { draftId }

    /// Project a typed draft out of a decoded JSON object; nil if the required fields are missing.
    init?(json: JSONValue) {
        guard let o = json.objectValue,
              let draftId = o["draftId"]?.stringValue,
              let tool = o["tool"]?.stringValue,
              let summary = o["summary"]?.stringValue else { return nil }
        self.raw = json
        self.draftId = draftId
        self.tool = tool
        self.summary = summary
        self.amount = o["amount"]?.doubleValue
        self.currency = o["currency"]?.stringValue
        self.blocked = o["blocked"]?.boolValue ?? false
        self.blockReason = o["blockReason"]?.stringValue
        self.params = o["params"]?.objectValue ?? [:]
        self.expiresAt = o["expiresAt"]?.stringValue
    }
}

// MARK: - Confirm result

/// Result of a confirmed action's simulation (`POST /ai/confirm-action` response).
struct AIConfirmResult: Decodable, Hashable, Sendable {
    let status: String        // "executed" | "rejected"
    let tool: String
    let message: String
    var reason: String?
    var result: JSONValue?

    var isExecuted: Bool { status == "executed" }
}

// MARK: - Stream events

/// One event from the copilot SSE stream. Names map 1:1 onto the backend's `SSEEvent`.
enum AIStreamEvent: Hashable, Sendable {
    case token(String)
    case toolDraft(AIToolDraft)
    case done(escalated: Bool)
}
