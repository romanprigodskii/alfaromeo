import Foundation
import Observation

/// The client side of the **real** demo wallet (§11.3) — the closed ₽ + fake-crypto economy that lives
/// on the backend (`/auth/register-demo`, `/balance`, `/users`, `/transfer`, `/crypto-transfer`). The
/// app injects ``MockAPIClient`` app-wide, so — like ``LivePriceService`` — this service talks to the
/// production backend directly. It is the single source of truth for *my* ₽ balance and crypto
/// holdings, so two devices on different phone numbers show different **real** balances from the server,
/// and a transfer actually moves money/coin between them.
///
/// Shared `@MainActor @Observable` singleton: the dashboard, the crypto hub, and every transfer flow
/// read one balance book.
@MainActor
@Observable
final class WalletService {
    static let shared = WalletService()

    /// My normalized phone (`+7XXXXXXXXXX`), set once I register/log in.
    private(set) var phone: String?
    private(set) var displayName: String?
    private(set) var balanceRub: Double = 0
    /// Crypto holdings keyed by UPPERCASE symbol (BTC / ETH / USDT / TON).
    private(set) var crypto: [String: Double] = [:]
    private(set) var registered = false
    /// All registered users (for the recipient picker) — refreshed lazily.
    private(set) var users: [WalletUser] = []

    private let base = APIEnvironment.production.baseURL
    private let session = URLSession.shared
    private init() {}

    // MARK: - DTOs

    struct WalletUser: Decodable, Identifiable, Hashable {
        let phone: String
        let displayName: String
        var id: String { phone }
    }
    /// The `/balance` body (and the `from`/`to` legs of a transfer response).
    fileprivate struct Balance: Decodable {
        let phone: String
        let displayName: String
        let balance: Double
        let btc: Double
        let eth: Double
        let usdt: Double
        let ton: Double
    }
    private struct TransferResp: Decodable { let amount: Double; let from: Balance; let to: Balance }
    struct CryptoTransferResult: Decodable {
        let asset: String
        let amount: Double
        fileprivate let from: Balance
        fileprivate let to: Balance
        /// Recipient's new holding of the moved asset (for the success copy: «у получателя стало …»).
        var recipientNewHolding: Double {
            switch asset.uppercased() {
            case "BTC": return to.btc
            case "ETH": return to.eth
            case "USDT": return to.usdt
            case "TON": return to.ton
            default: return 0
            }
        }
    }

    /// Friendly, non-crashing errors mapped from the backend's `{ error, message }` bodies.
    enum WalletError: LocalizedError {
        case insufficientFunds
        case insufficientAsset(String)
        case recipientNotFound
        case sameAccount
        case invalidAmount
        case notRegistered
        case network
        case server(String)

        var errorDescription: String? {
            switch self {
            case .insufficientFunds:      return "Недостаточно средств на балансе."
            case .insufficientAsset(let a): return "Недостаточно \(a) на балансе."
            case .recipientNotFound:      return "Получатель не зарегистрирован в демо."
            case .sameAccount:            return "Нельзя переводить самому себе."
            case .invalidAmount:          return "Некорректная сумма."
            case .notRegistered:          return "Сначала войдите по номеру телефона."
            case .network:                return "Нет связи с сервером. Попробуйте ещё раз."
            case .server(let m):          return m
            }
        }
    }

    // MARK: - Reads

    func cryptoBalance(_ asset: String) -> Double { crypto[asset.uppercased()] ?? 0 }

    /// Recipients for a transfer — everyone registered except me.
    var recipients: [WalletUser] { users.filter { $0.phone != phone } }

    // MARK: - Session

    /// Register (idempotent on the server — keeps a seeded balance) and load my balance + the user list.
    func register(phone: String, displayName: String) async {
        self.phone = phone
        self.displayName = displayName
        if let b: Balance = try? await postBestEffort("auth/register-demo", ["phone": phone, "displayName": displayName]) {
            apply(b)
        }
        await refreshBalance()
        await refreshUsers()
    }

    func refreshBalance() async {
        guard let phone else { return }
        if let b: Balance = try? await get("balance", query: [URLQueryItem(name: "phone", value: phone)]) { apply(b) }
    }

    func refreshUsers() async {
        struct UsersResp: Decodable { let users: [WalletUser] }
        if let r: UsersResp = try? await get("users") { users = r.users }
    }

    // MARK: - Transfers

    /// Move ₽ to a registered recipient. Updates my balance from the response. Throws ``WalletError``.
    @discardableResult
    func transfer(toPhone: String, amountRub: Double) async throws -> Double {
        guard let phone else { throw WalletError.notRegistered }
        let resp: TransferResp = try await post("transfer", ["fromPhone": phone, "toPhone": toPhone, "amount": amountRub])
        apply(resp.from)
        return resp.to.balance
    }

    /// Move a crypto asset to a registered recipient (real server move). Updates my holdings. Throws.
    @discardableResult
    func cryptoTransfer(toPhone: String, asset: String, amount: Double) async throws -> CryptoTransferResult {
        guard let phone else { throw WalletError.notRegistered }
        let resp: CryptoTransferResult = try await post(
            "crypto-transfer",
            ["fromPhone": phone, "toPhone": toPhone, "asset": asset.uppercased(), "amount": amount])
        apply(resp.from)
        return resp
    }

    // MARK: - Private

    private func apply(_ b: Balance) {
        guard b.phone == phone else { return }
        balanceRub = b.balance
        crypto = ["BTC": b.btc, "ETH": b.eth, "USDT": b.usdt, "TON": b.ton]
        displayName = b.displayName
        registered = true
    }

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { c?.queryItems = query }
        return c?.url ?? base.appendingPathComponent(path)
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var req = URLRequest(url: url(path, query: query))
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(req)
    }

    /// POST that maps a non-2xx `{ error }` body to a ``WalletError`` (used for transfers).
    private func post<T: Decodable>(_ path: String, _ body: [String: Any]) async throws -> T {
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    /// POST used during register — never throws to the caller (best-effort; nil on any failure).
    private func postBestEffort<T: Decodable>(_ path: String, _ body: [String: Any]) async throws -> T {
        try await post(path, body)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw WalletError.network
        }
        guard let http = response as? HTTPURLResponse else { throw WalletError.network }
        guard (200..<300).contains(http.statusCode) else { throw Self.mapError(data) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw WalletError.server("Не удалось прочитать ответ сервера.")
        }
    }

    /// Map a backend error body `{ "error": "...", "message": "..." }` to a friendly ``WalletError``.
    private static func mapError(_ data: Data) -> WalletError {
        struct Body: Decodable { let error: String?; let message: String?; let asset: String? }
        guard let b = try? JSONDecoder().decode(Body.self, from: data) else { return .network }
        switch b.error {
        case "insufficient_funds":                       return .insufficientFunds
        case "insufficient_asset":                       return .insufficientAsset(b.asset ?? "актива")
        case "recipient_not_found", "sender_not_found":  return .recipientNotFound
        case "same_account":                             return .sameAccount
        case "invalid_amount", "invalid_asset", "invalid_phone": return .invalidAmount
        default:                                         return .server(b.message ?? "Ошибка сервера.")
        }
    }
}
