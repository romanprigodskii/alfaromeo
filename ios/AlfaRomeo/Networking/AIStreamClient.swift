import Foundation

/// AI copilot transport (§10.9 / §11.7).
///
/// `.live` talks to OUR backend — SSE over `POST /ai/chat` and REST `POST /ai/confirm-action` — never to
/// Anthropic directly (the key lives on the backend, same rule as live prices). `.mock` is a deterministic,
/// intent-aware demo engine (typewriter stream + locally-built drafts + simulated confirm) so the whole
/// copilot — including the agentic confirm flow — is demonstrable offline. ``CopilotService`` picks live,
/// falling back to mock when the backend is unreachable.
struct AIStreamClient: Sendable {
    enum Mode: Sendable { case mock, live }

    let mode: Mode
    var baseURL: URL
    var session: URLSession

    init(mode: Mode = .mock, baseURL: URL = APIEnvironment.current.baseURL, session: URLSession = .shared) {
        self.mode = mode
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Streaming

    /// Full chat turn: conversation history + mode + profile scope → SSE events.
    func stream(messages: [AIChatMessage], mode chatMode: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        switch mode {
        case .mock: return mockStream(messages: messages, chatMode: chatMode, profileId: profileId)
        case .live: return liveStream(messages: messages, chatMode: chatMode, profileId: profileId)
        }
    }

    /// Convenience for a single user turn (debug harness / quick prompts), support mode.
    func stream(prompt: String, profileId: String = "profile-personal-demo") -> AsyncThrowingStream<AIStreamEvent, Error> {
        stream(messages: [AIChatMessage(role: "user", content: prompt)], mode: "support", profileId: profileId)
    }

    // MARK: Confirm action

    /// Execute a biometric-confirmed draft. `.live` → `POST /ai/confirm-action`; the draft is echoed via
    /// its raw JSON so the server's HMAC re-derivation matches. `.mock` simulates locally.
    func confirmAction(draft: AIToolDraft, profileId: String) async throws -> AIConfirmResult {
        switch mode {
        case .mock: return Self.mockConfirm(draft: draft)
        case .live: return try await liveConfirm(draft: draft, profileId: profileId)
        }
    }

    // MARK: - Live (SSE)

    private func liveStream(messages: [AIChatMessage], chatMode: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("ai/chat"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue(profileId, forHTTPHeaderField: "X-Profile-Id")
                    request.timeoutInterval = 60
                    request.httpBody = try JSONEncoder().encode(
                        AIChatRequest(profileId: profileId, mode: chatMode, messages: messages))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                    guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }

                    var eventName = "message"
                    var dataLines: [String] = []

                    func dispatch() {
                        defer { eventName = "message"; dataLines.removeAll() }
                        guard !dataLines.isEmpty,
                              let data = dataLines.joined(separator: "\n").data(using: .utf8) else { return }
                        switch eventName {
                        case "token":
                            if let text = (try? JSONDecoder().decode(JSONValue.self, from: data))?["text"]?.stringValue {
                                continuation.yield(.token(text))
                            }
                        case "toolDraft":
                            if let json = try? JSONDecoder().decode(JSONValue.self, from: data),
                               let draft = AIToolDraft(json: json) {
                                continuation.yield(.toolDraft(draft))
                            }
                        case "done":
                            let escalated = (try? JSONDecoder().decode(JSONValue.self, from: data))?["escalated"]?.boolValue ?? false
                            continuation.yield(.done(escalated: escalated))
                        default:
                            break
                        }
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if line.isEmpty { dispatch(); continue }       // blank line ends an SSE frame
                        if line.hasPrefix(":") { continue }            // comment / heartbeat
                        if let v = Self.field(line, "event:") { eventName = v }
                        else if let v = Self.field(line, "data:") { dataLines.append(v) }
                    }
                    dispatch()                                          // flush a trailing frame
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    if Task.isCancelled { continuation.finish() }
                    else { continuation.finish(throwing: error) }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func liveConfirm(draft: AIToolDraft, profileId: String) async throws -> AIConfirmResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("ai/confirm-action"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(profileId, forHTTPHeaderField: "X-Profile-Id")
        request.timeoutInterval = 30
        // Echo the draft verbatim (raw JSON) so the server re-derives the same HMAC over its field values.
        let body = JSONValue.object(["profileId": .string(profileId), "draft": draft.raw])
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.http(status: http.statusCode) }
        do { return try JSONDecoder().decode(AIConfirmResult.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    /// Strip an SSE field prefix and the single optional leading space after the colon.
    private static func field(_ line: String, _ prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        var value = String(line.dropFirst(prefix.count))
        if value.hasPrefix(" ") { value.removeFirst() }
        return value
    }

    // MARK: - Mock (deterministic offline demo)

    private func mockStream(messages: [AIChatMessage], chatMode: String, profileId: String) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let text = messages.last(where: { $0.role == "user" })?.content ?? ""
                let intent = Self.classify(text)
                let isAgent = chatMode == "agent"
                var escalated = false

                func say(_ s: String) async {
                    for word in s.split(separator: " ", omittingEmptySubsequences: false) {
                        if Task.isCancelled { return }
                        try? await Task.sleep(for: .milliseconds(26))
                        continuation.yield(.token(String(word) + " "))
                    }
                }

                switch intent {
                case .transfer(let recipient, let amount, let currency):
                    if !isAgent {
                        await say("Переводы я готовлю в режиме «Агент». Переключитесь — и я соберу черновик с подтверждением по Face ID.")
                    } else if let recipient {
                        await say("Готовлю черновик перевода \(Self.fmt(amount)) \(currency) получателю «\(recipient)». Подтвердите по Face ID — и я выполню.")
                        if !Task.isCancelled {
                            continuation.yield(.toolDraft(Self.localDraft(
                                tool: "make_transfer",
                                summary: "Перевод \(Self.fmt(amount)) \(currency) получателю «\(recipient)»",
                                params: ["to": .string(recipient), "amount": .number(amount), "currency": .string(currency)],
                                amount: amount, currency: currency)))
                        }
                    } else {
                        await say("Кому перевести? Уточните получателя — имя из контактов или номер телефона.")
                    }
                case .deposit(let amount, let isStake):
                    if !isAgent {
                        await say("Открыть вклад можно в режиме «Агент» — подготовлю черновик с подтверждением по Face ID.")
                    } else {
                        await say("Готовлю черновик \(isStake ? "крипто-стейка" : "вклада") на \(Self.fmt(amount)) ₽. Подтвердите по Face ID.")
                        if !Task.isCancelled {
                            let params: [String: JSONValue] = isStake
                                ? ["amount": .number(amount), "type": .string("stake")]
                                : ["amount": .number(amount), "term": .int(6), "type": .string("ruble")]
                            continuation.yield(.toolDraft(Self.localDraft(
                                tool: "open_deposit",
                                summary: isStake ? "Крипто-стейк на \(Self.fmt(amount)) ₽" : "Рублёвый вклад \(Self.fmt(amount)) ₽ на 6 мес.",
                                params: params, amount: amount, currency: "RUB")))
                        }
                    }
                case .freeze:
                    if !isAgent {
                        await say("Заморозку карты выполню в режиме «Агент» — с подтверждением по Face ID.")
                    } else {
                        await say("Готовлю черновик заморозки карты ··4921. Подтвердите по Face ID.")
                        if !Task.isCancelled {
                            continuation.yield(.toolDraft(Self.localDraft(
                                tool: "freeze_card",
                                summary: "Заморозка карты ··4921",
                                params: ["cardId": .string("card-virt")],
                                amount: nil, currency: nil)))
                        }
                    }
                case .balance:
                    await say("Вот балансы по вашим счетам: текущий — 184 200 ₽; накопительный — 320 500 ₽; крипто ≈ 412 000 ₽. Нужна детализация или перевод? Я рядом.")
                case .escalate:
                    await say("Подключаю оператора — создал обращение SUP-DEMO. Живой специалист ответит в этом чате. Чем ещё помочь?")
                    escalated = true
                case .general:
                    await say(isAgent
                        ? "Я Claude-копилот Альфа-Ромео. В режиме «Агент» могу подготовить перевод, вклад или заморозку карты — с подтверждением по Face ID. Что хотите сделать?"
                        : "Я Claude-копилот Альфа-Ромео. Помогу со счетами, картами, переводами, вкладами и криптой. Спросите, например, «какой у меня баланс».")
                }

                if !Task.isCancelled { continuation.yield(.done(escalated: escalated)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func mockConfirm(draft: AIToolDraft) -> AIConfirmResult {
        if draft.blocked {
            return AIConfirmResult(status: "rejected", tool: draft.tool, message: "Действие отклонено.",
                                   reason: draft.blockReason ?? "Превышен лимит AI-агента.", result: nil)
        }
        let message: String
        switch draft.tool {
        case "make_transfer":
            message = "Перевод \(fmt(draft.amount ?? 0)) \(draft.currency ?? "RUB") выполнен · TX-\(shortId())"
        case "open_deposit":
            message = "Открыт вклад на \(fmt(draft.amount ?? 0)) ₽ · DEP-\(shortId())"
        default:
            message = "Карта заморожена · CARD-\(shortId())"
        }
        return AIConfirmResult(status: "executed", tool: draft.tool, message: message, reason: nil, result: nil)
    }

    // MARK: Mock helpers

    private enum MockIntent {
        case transfer(recipient: String?, amount: Double, currency: String)
        case deposit(amount: Double, isStake: Bool)
        case freeze
        case balance
        case escalate
        case general
    }

    private static func classify(_ raw: String) -> MockIntent {
        let t = raw.lowercased()
        func has(_ p: String) -> Bool { t.range(of: p, options: .regularExpression) != nil }
        let informational = has("(^|\\s)как\\s|что такое|какая комисс|сколько стоит|можно ли|расскажи|подскажи|чем отлич")

        if !informational && has("перевед|отправь|перечисли|скинь") {
            return .transfer(recipient: recipient(raw), amount: amount(t) ?? 0, currency: currency(t))
        }
        if !informational && has("вклад|депозит|застейк|стейк") && has("открой|оформи|сделай|положи|хочу|застейк") {
            return .deposit(amount: amount(t) ?? 0, isStake: has("стейк|крипт|btc|eth|usdt"))
        }
        if !informational && has("заморозь|заблокируй карт|потерял карт|украли карт|freeze") {
            return .freeze
        }
        if has("баланс|сколько у меня|сколько денег|остаток|свободн") { return .balance }
        if has("оператор|человек|поддержк|менеджер|жалоб|свяжите") { return .escalate }
        return .general
    }

    private static let relations = ["маме", "папе", "жене", "мужу", "брату", "сестре", "другу", "подруге", "сыну", "дочери", "бабушке", "дедушке"]

    private static func recipient(_ raw: String) -> String? {
        let lower = raw.lowercased()
        for r in relations where lower.contains(r) { return r }
        if let m = raw.range(of: "[А-ЯЁ][а-яё]{2,}", options: .regularExpression) {
            let name = String(raw[m])
            if !["Переведи", "Отправь", "Перечисли", "Скинь"].contains(name) { return name }
        }
        return nil
    }

    private static func amount(_ t: String) -> Double? {
        // Collapse digit grouping (regular / non-breaking / thin spaces) so «5 000» reads as 5000.
        let collapsed = t
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{2009}", with: "")
        guard let m = collapsed.range(of: "\\d+([.,]\\d+)?", options: .regularExpression) else { return nil }
        return Double(collapsed[m].replacingOccurrences(of: ",", with: "."))
    }

    private static func currency(_ t: String) -> String {
        if t.contains("usdt") { return "USDT" }
        if t.range(of: "btc|биткоин|бткоин", options: .regularExpression) != nil { return "BTC" }
        if t.range(of: "eth|эфир", options: .regularExpression) != nil { return "ETH" }
        if t.range(of: "доллар|usd|\\$", options: .regularExpression) != nil { return "USD" }
        return "RUB"
    }

    private static func localDraft(tool: String, summary: String, params: [String: JSONValue],
                                   amount: Double?, currency: String?) -> AIToolDraft {
        let expires = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600))
        let obj: [String: JSONValue] = [
            "draftId": .string("mock-" + UUID().uuidString),
            "tool": .string(tool),
            "name": .string(tool),
            "summary": .string(summary),
            "params": .object(params),
            "amount": amount.map(JSONValue.number) ?? .null,
            "currency": currency.map(JSONValue.string) ?? .null,
            "requiresBiometric": .bool(true),
            "blocked": .bool(false),
            "blockReason": .null,
            "signature": .string("mock-local"),
            "expiresAt": .string(expires),
        ]
        // Force-unwrap is safe: the object we just built has every required field.
        return AIToolDraft(json: .object(obj))!
    }

    private static func shortId() -> String { String(UUID().uuidString.prefix(8)).uppercased() }

    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()
    private static func fmt(_ n: Double) -> String { numberFormatter.string(from: NSNumber(value: n)) ?? "\(n)" }
}
