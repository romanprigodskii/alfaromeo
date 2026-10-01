import Foundation
import Observation

/// «Отправить крипту» (§9.6): контакту (по телефону, как Revolut) / на адрес / по QR, с выбором сети
/// и превью комиссии сети. Mirrors ``TransferFlowModel`` (form → confirm → biometric → status), prices
/// in ₽ via ``LivePriceService``, simulates settlement, and demonstrates two edge cases: «сеть
/// перегружена» (the ERC-20 network is flagged congested) and «недостаточно средств» (§10.8).
@MainActor
@Observable
final class SendCryptoModel {
    enum Step: Hashable { case form, confirm, status }
    enum RecipientMode: String, CaseIterable, Identifiable {
        case contact, address, qr
        var id: String { rawValue }
        var label: String {
            switch self {
            case .contact: return "Контакту"
            case .address: return "На адрес"
            case .qr:      return "По QR"
            }
        }
        var icon: String {
            switch self {
            case .contact: return "person.crop.circle.fill"
            case .address: return "number"
            case .qr:      return "qrcode.viewfinder"
            }
        }
    }

    let asset: String
    var mode: RecipientMode = .contact
    var amountText = ""
    var inputInAsset = true
    var addressText = ""
    var selectedContact: PaymentContact?
    var qrScanned = false
    /// The address decoded from a scanned QR (or the simulator fallback) — shown on the QR tile + confirm.
    var scannedAddress: String?

    let networks: [CryptoNetwork]
    var network: CryptoNetwork?

    var investorStatus: InvestorStatus = .unqualified
    var step: Step = .form
    var authorizing = false
    var outcome: CryptoOutcome?

    /// Registered recipients from the backend (`/users`) — a crypto move targets a real user by phone.
    var registeredContacts: [PaymentContact] = []

    private var retriedAfterCongestion = false

    init(asset: String) {
        self.asset = asset.uppercased()
        let nets = CryptoCatalog.networks(for: asset)
        self.networks = nets
        self.network = nets.first
    }

    func load(session: AppSession) {
        investorStatus = session.currentUser?.investorStatus ?? .unqualified
    }

    /// Pull the registered users so the contact picker offers real recipients (excluding me).
    func refreshRecipients() async {
        await WalletService.shared.refreshUsers()
        registeredContacts = WalletService.shared.recipients.map {
            PaymentContact(id: $0.phone, name: $0.displayName, phone: $0.phone, bank: "Ромео")
        }
    }

    // MARK: Derived

    private var raw: Double { CryptoFormat.parse(amountText) }
    var assetPrice: Double { LivePriceService.shared.price(asset) }
    var assetAmount: Double { inputInAsset ? raw : (assetPrice > 0 ? raw / assetPrice : 0) }
    var rubAmount: Double { assetAmount * assetPrice }
    var feeRub: Double { network?.feeRub ?? 0 }
    var balance: Double { CryptoStore.shared.bankBalance(asset: asset) }

    var recipientLabel: String {
        switch mode {
        case .contact: return selectedContact?.name ?? "Контакт"
        case .address: return shortAddress(addressText)
        case .qr:      return scannedAddress.map(shortAddress) ?? "QR-адрес"
        }
    }
    var recipientDetail: String {
        switch mode {
        case .contact:
            guard let c = selectedContact else { return "Выберите контакт" }
            return c.hasWallet ? (c.walletShort ?? c.phone) : "Пригласить, кошелёк создастся автоматически"
        case .address: return addressText.isEmpty ? "Вставьте адрес кошелька" : shortAddress(addressText)
        case .qr:      return qrScanned ? (scannedAddress.map(shortAddress) ?? "Отсканирован") : "Наведите камеру на QR"
        }
    }

    var recipientReady: Bool {
        switch mode {
        case .contact: return selectedContact != nil
        case .address: return addressText.trimmingCharacters(in: .whitespaces).count >= 8
        case .qr:      return qrScanned
        }
    }

    // MARK: Gate (crypto investor limit, §2.4)

    enum Gate: Equatable { case ok, empty, noRecipient, investorLimit(remaining: Double) }
    var gate: Gate {
        guard raw > 0 else { return .empty }
        guard recipientReady else { return .noRecipient }
        if CryptoStore.shared.cryptoTradeExceedsLimit(rub: rubAmount, investorStatus: investorStatus) {
            return .investorLimit(remaining: CryptoStore.shared.investorRemainingRub)
        }
        return .ok
    }
    var canProceed: Bool { gate == .ok }
    var insufficientFunds: Bool { assetAmount > balance }

    // MARK: Steps

    func goToConfirm() { if canProceed { step = .confirm } }
    func backToForm() { step = .form }

    /// Apply an address decoded from a scanned QR (or the simulator fallback). Strips a payment-URI
    /// scheme (`ethereum:` / `bitcoin:` / `ton:`) and any `?amount=…` query, keeping the bare address.
    func applyScannedAddress(_ raw: String) {
        let addr = Self.decodeAddress(raw)
        guard !addr.isEmpty else { return }
        addressText = addr
        scannedAddress = addr
        qrScanned = true
        mode = .qr
    }

    static func decodeAddress(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // `scheme:payload` (e.g. ethereum:0x…, bitcoin:bc1…) → keep payload. Guard against an address
        // that itself contains ':' by only treating a leading all-letters token as a scheme.
        if let colon = s.firstIndex(of: ":") {
            let scheme = s[s.startIndex..<colon]
            if !scheme.isEmpty && scheme.allSatisfy({ $0.isLetter }) {
                s = String(s[s.index(after: colon)...])
            }
        }
        if let q = s.firstIndex(of: "?") { s = String(s[s.startIndex..<q]) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func authorize() async {
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(reason: "Отправить \(CryptoFormat.qty(assetAmount, symbol: asset))")
        authorizing = false
        guard ok else { outcome = .declined(.canceled); step = .status; return }
        outcome = .processing
        step = .status

        // Sending to a registered contact → REAL server move via /crypto-transfer (the coin actually
        // moves to the recipient's device). Address/QR modes have no registered phone → local demo.
        if mode == .contact, let toPhone = selectedContact?.phone {
            do {
                _ = try await WalletService.shared.cryptoTransfer(toPhone: toPhone, asset: asset, amount: assetAmount)
                await CryptoStore.shared.reloadServerBalances()
                outcome = .success
            } catch let e as WalletService.WalletError {
                outcome = .declined(Self.mapError(e))
            } catch {
                outcome = .declined(.failed("Не удалось отправить. Попробуйте ещё раз."))
            }
            return
        }

        try? await Task.sleep(for: .seconds(1.4))
        let result = computeSettlement()
        if case .success = result {
            CryptoStore.shared.send(asset: asset, qty: assetAmount, rubValue: rubAmount,
                                    to: recipientLabel, network: network?.name ?? "")
        }
        outcome = result
    }

    private static func mapError(_ e: WalletService.WalletError) -> CryptoDeclineReason {
        switch e {
        case .insufficientAsset, .insufficientFunds: return .insufficientFunds
        case .network:                               return .networkBusy
        default:                                     return .failed(e.errorDescription ?? "Ошибка перевода.")
        }
    }

    func retry() {
        guard let outcome else { return }
        if case .declined(let reason) = outcome {
            // A congested-network decline retries the send; everything else returns to the form.
            self.outcome = nil
            step = (reason == .networkBusy) ? .confirm : .form
        }
    }

    private func computeSettlement() -> CryptoOutcome {
        if insufficientFunds { return .declined(.insufficientFunds) }
        if (network?.congested ?? false) && !retriedAfterCongestion {
            retriedAfterCongestion = true
            return .declined(.networkBusy)
        }
        return .success
    }

    private func shortAddress(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count > 12 else { return t }
        return "\(t.prefix(6))…\(t.suffix(4))"
    }
}
