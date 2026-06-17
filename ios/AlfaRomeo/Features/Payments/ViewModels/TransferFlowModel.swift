import SwiftUI
import Observation

/// The engine behind ``TransferFlowView`` — one ``@Observable`` driving every rail of §10.3:
/// recipient → сумма → подтверждение(биометрия) → статус. Computes the ₽-эквивалент of crypto by
/// mock rate (``APIClient/prices(assets:)``), the комиссия, and the edge-case gates
/// (недостаточно средств / лимит операции / неквал-инвестор), then simulates settlement.
@MainActor
@Observable
final class TransferFlowModel {

    enum Step: Hashable { case recipient, amount, confirm, status }

    /// Pre-flight gate evaluated at the amount step. `.ok` lets the user continue; the others block
    /// with a message. Insufficient funds is intentionally *not* here — it passes pre-flight and is
    /// declined at settlement, so the «Операция отклонена…» status is reachable by user action.
    enum Gate: Equatable {
        case ok
        case empty
        case overLimit(Double)
        case investorLimit(remaining: Double)
    }

    let kind: TransferKind
    let prefilledBiller: Biller?

    var step: Step

    // MARK: Recipient (finalized) + entry fields
    var recipient: Recipient?
    var phone = ""
    /// The normalized recipient phone for a real ₽ move (СБП / by-card) via /transfer.
    var recipientPhone: String?
    /// Registered recipients from the backend (`/users`).
    var registeredContacts: [PaymentContact] = []
    var selectedContactId: String?
    var cardNumber = ""
    var account = ""
    var bik = ""
    var inn = ""
    var receiverName = ""
    var country = "Сербия"
    var iban = ""
    var qrScanned = false

    // MARK: Sources
    var accounts: [Account] = []
    var wallets: [CryptoWallet] = []
    var sourceAccount: Account?           // fiat rails
    var sourceWallet: CryptoWallet?       // crypto rail
    var destinationAccount: Account?      // between accounts

    // MARK: Amount
    var amountText = ""
    var inputInRub = false                // crypto toggle: enter ₽ vs asset units

    // MARK: Pricing / tier
    var prices: [String: Double] = [:]    // asset → ₽ per unit (mock)
    var freeAbroad = false
    var investorStatus: InvestorStatus = .unqualified

    // MARK: Submission
    var authorizing = false
    var outcome: OperationOutcome?

    // MARK: - Init

    init(kind: TransferKind, biller: Biller? = nil) {
        self.kind = kind
        self.prefilledBiller = biller
        if let biller {
            recipient = biller.recipient()
            if let suggested = biller.suggestedAmount { amountText = Self.plain(suggested) }
            step = .amount
        } else {
            step = .recipient
        }
    }

    // MARK: - Loading

    func load(api: any APIClient, session: AppSession) async {
        let profileId = session.activeProfile?.id ?? ""
        investorStatus = session.currentUser?.investorStatus ?? .unqualified

        async let accountsTask = (try? await api.accounts(profileId: profileId)) ?? []
        async let walletsTask = (try? await api.cryptoWallets(profileId: profileId)) ?? []
        accounts = await accountsTask
        wallets = await walletsTask

        // Default sources per rail.
        if kind.isCrypto {
            sourceWallet = sourceWallet ?? wallets.first
            let assets = wallets.map(\.asset)
            if let ticks = try? await api.prices(assets: assets.isEmpty ? ["BTC", "ETH", "USDT", "SOL"] : assets) {
                // Keep the last tick per asset — `uniqueKeysWithValues` would TRAP on a duplicate
                // asset (e.g. USDT on two chains), which `try?` can't catch.
                prices = Dictionary(ticks.map { ($0.asset, $0.price) }, uniquingKeysWith: { _, new in new })
            }
        } else {
            sourceAccount = sourceAccount ?? defaultFiatSource()
        }

        // Tier → free abroad transfers (§4.1).
        let fallback = (try? await api.subscription(profileId: profileId))?.tier ?? .base
        let tier = session.currentTier(for: profileId, fallback: fallback)
        freeAbroad = Entitlements.make(for: tier).freeAbroadTransfers

        // Real registered recipients (for СБП / by-card P2P moves through /transfer).
        await WalletService.shared.refreshUsers()
        registeredContacts = WalletService.shared.recipients.map {
            PaymentContact(id: $0.phone, name: $0.displayName, phone: $0.phone, bank: "СБП")
        }
    }

    /// True for the rails that move real ₽ between two registered users via the backend `/transfer`.
    private var isRealRubRail: Bool { kind == .byPhone || kind == .byCard }

    private func defaultFiatSource() -> Account? {
        switch kind {
        case .digitalRubleQR:
            return accounts.first { $0.type == .digitalRuble } ?? accounts.first { $0.isRubLike }
        default:
            return accounts.first { $0.type == .current } ?? accounts.first { $0.isRubLike }
        }
    }

    /// Accounts offered as the source for the current rail (RUB-like; crypto rail uses wallets).
    var eligibleSources: [Account] {
        accounts.filter { $0.isRubLike }
    }

    /// Between-accounts: the destination candidates (everything except the chosen source).
    var destinationCandidates: [Account] {
        accounts.filter { $0.id != sourceAccount?.id }
    }

    // MARK: - Amount math

    private var rawAmount: Double {
        let cleaned = amountText
            .replacingOccurrences(of: "\u{2009}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    /// The asset (ticker) for the crypto rail.
    var asset: String { sourceWallet?.asset ?? "USDT" }
    var assetPrice: Double { prices[asset] ?? 0 }

    /// Amount in asset units (crypto rail).
    var assetAmount: Double {
        guard kind.isCrypto else { return 0 }
        if inputInRub { return assetPrice > 0 ? rawAmount / assetPrice : 0 }
        return rawAmount
    }

    /// Amount expressed in ₽ — the unified equivalent (§11.4). For fiat rails it's the entered amount.
    var rubAmount: Double {
        if kind.isCrypto { return assetAmount * assetPrice }
        return rawAmount
    }

    /// The ₽-эквивалент shown for crypto rails (nil for fiat).
    var rubEquivalent: Double? { kind.isCrypto ? rubAmount : nil }

    /// Mock комиссия (₽). Free СБП / between-accounts / digital ruble; tier-free abroad (§4.1).
    var fee: Double {
        guard rawAmount > 0 else { return 0 }
        switch kind {
        case .betweenAccounts, .byPhone, .byRequisites, .digitalRubleQR:
            return 0
        case .byCard:
            return max(rubAmount * 0.015, 30)
        case .abroad:
            return freeAbroad ? 0 : (rubAmount * 0.01 + 99)
        case .cryptoToContact:
            return 35   // «превью комиссии сети» (mock)
        }
    }

    /// Total ₽ leaving a fiat source (amount + fee). Crypto debits the wallet in asset units.
    var totalDebitRub: Double { rubAmount + fee }

    /// Available balance for the current source, in its own units. For the real ₽ rails the source of
    /// truth is the live backend wallet (``WalletService``), so «Доступно» matches what /transfer enforces.
    var availableBalance: Double {
        if isRealRubRail, WalletService.shared.registered { return WalletService.shared.balanceRub }
        return kind.isCrypto ? (sourceWallet?.balance ?? 0) : (sourceAccount?.balance ?? 0)
    }

    var sourceSymbol: String {
        kind.isCrypto ? asset : (sourceAccount?.symbol ?? "₽")
    }

    /// Soft flag: the operation will likely be declined at settlement (недостаточно средств). Shown
    /// inline at the amount step, but does not block — the decline is demonstrated on the status step.
    var insufficientFunds: Bool {
        guard rawAmount > 0 else { return false }
        if kind.isCrypto { return assetAmount > availableBalance }
        return totalDebitRub > availableBalance
    }

    // MARK: - Pre-flight gate

    var gate: Gate {
        guard rawAmount > 0 else { return .empty }
        if kind.isCrypto, investorStatus == .unqualified {
            let projected = PaymentsMockData.nonQualUsedThisYearRub + rubAmount
            if projected > PaymentsMockData.nonQualYearlyLimitRub {
                return .investorLimit(remaining: PaymentsMockData.nonQualRemainingRub)
            }
        }
        if let limit = PaymentsMockData.perOperationLimit(for: kind), rubAmount > limit {
            return .overLimit(limit)
        }
        return .ok
    }

    var canProceed: Bool { gate == .ok }

    // MARK: - Step transitions

    /// The first step of this flow — recipient normally, or amount when launched from a biller.
    var atFirstStep: Bool {
        prefilledBiller != nil ? step == .amount : step == .recipient
    }

    func goToAmount() { step = .amount }
    func goToConfirm() { if canProceed { step = .confirm } }
    func backToAmount() { step = .amount }

    /// In-flow back (the chevron) — one step toward the start, never out of the flow.
    func stepBack() {
        switch step {
        case .recipient, .status: break
        case .amount:  if prefilledBiller == nil { step = .recipient }
        case .confirm: step = .amount
        }
    }

    /// Quick-chip increment on the amount field.
    func addAmount(_ value: Double) { amountText = Self.plain(rawAmount + value) }

    /// Confirm via biometrics (§10.3) → animated status. A biometric cancel / failure is the «отмена»
    /// edge case — it surfaces as the animated «Операция отменена» status (средства не списаны).
    func authorize() async {
        authorizing = true
        let ok = await BiometricAuthenticator.authenticate(
            reason: "\(kind.actionVerb): \(recipient?.name ?? "получателю")"
        )
        authorizing = false
        guard ok else {
            outcome = .declined(.canceled)
            step = .status
            return
        }
        outcome = .processing
        step = .status

        // Real ₽ move between two registered users (СБП by phone / by card) → backend /transfer; the
        // recipient's balance actually grows on their device. Other rails stay local demo (unchanged).
        if isRealRubRail, let toPhone = recipientPhone {
            do {
                _ = try await WalletService.shared.transfer(toPhone: toPhone, amountRub: rubAmount)
                outcome = .success
            } catch let e as WalletService.WalletError {
                outcome = .declined(Self.mapError(e))
            } catch {
                outcome = .declined(.failed("Не удалось перевести. Попробуйте ещё раз."))
            }
            return
        }

        try? await Task.sleep(for: .seconds(1.4))   // «в обработке»
        outcome = settle()
    }

    /// Deterministic settlement (non-backend rails): declines on insufficient funds, else succeeds.
    private func settle() -> OperationOutcome {
        insufficientFunds ? .declined(.insufficientFunds) : .success
    }

    private static func mapError(_ e: WalletService.WalletError) -> DeclineReason {
        switch e {
        case .insufficientFunds, .insufficientAsset: return .insufficientFunds
        default:                                     return .failed(e.errorDescription ?? "Ошибка перевода.")
        }
    }

    /// From a declined status: a cancel returns to confirm (re-authorize); a money decline returns to
    /// the amount step to adjust.
    func retry() {
        let wasCanceled = outcome == .declined(.canceled)
        outcome = nil
        step = wasCanceled ? .confirm : .amount
    }

    // MARK: - Recipient builders (called by the recipient step)

    func selectContactSBP(_ contact: PaymentContact) {
        selectedContactId = contact.id
        phone = contact.phone
        recipientPhone = MockData.normalizePhone(contact.phone)
        recipient = contact.sbpRecipient()
        step = .amount
    }

    /// Pick a registered user as the recipient (used by the by-card rail so the move still lands on a
    /// real account through /transfer). The card number stays a cosmetic input.
    func selectRegisteredRecipient(_ contact: PaymentContact) {
        selectedContactId = contact.id
        phone = contact.phone
        recipientPhone = MockData.normalizePhone(contact.phone)
        recipient = Recipient(name: contact.name, detail: contact.phone, icon: "creditcard", bank: "карта")
        step = .amount
    }

    func selectContactCrypto(_ contact: PaymentContact) {
        selectedContactId = contact.id
        phone = contact.phone
        recipient = contact.cryptoRecipient()
        step = .amount
    }

    func commitTypedPhone() {
        guard phone.filter(\.isNumber).count >= 10 else { return }
        recipientPhone = MockData.normalizePhone(phone)
        recipient = Recipient(name: "Перевод по номеру", detail: phone, icon: "person.fill", bank: "СБП")
        step = .amount
    }

    func commitCard() {
        let digits = cardNumber.filter(\.isNumber)
        guard digits.count >= 16 else { return }
        recipient = Recipient(name: "Карта получателя", detail: "···· \(digits.suffix(4))", icon: "creditcard")
        step = .amount
    }

    func commitRequisites() {
        guard !receiverName.isEmpty, account.filter(\.isNumber).count >= 8 else { return }
        recipient = Recipient(name: receiverName,
                              detail: "Счёт ·· \(account.suffix(4)) · БИК \(bik)",
                              icon: "doc.text")
        step = .amount
    }

    func commitAbroad() {
        guard !iban.isEmpty else { return }
        recipient = Recipient(name: receiverName.isEmpty ? country : receiverName,
                              detail: "\(country) · \(iban.uppercased())",
                              icon: "globe")
        step = .amount
    }

    func commitQR() {
        qrScanned = true
        recipient = Recipient(name: "Цифровой рубль", detail: "QR · C2C · ЦБ-платформа", icon: "qrcode")
        step = .amount
    }

    func selectDestinationAccount(_ acc: Account) {
        destinationAccount = acc
        // Keep the source distinct from the destination (§10.3 «между счетами»).
        if sourceAccount == nil || sourceAccount?.id == acc.id {
            sourceAccount = accounts.first { $0.isRubLike && $0.id != acc.id }
        }
        recipient = Recipient(name: acc.displayTitle, detail: acc.displaySubtitle, icon: acc.type.paymentsIcon)
        step = .amount
    }

    // MARK: - Formatting helper

    /// A plain decimal string (no grouping) for seeding the amount field — locale-aware separator so
    /// a fractional value matches the ru decimalPad (comma), keeping the field editable.
    static func plain(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return plainFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
    private static let plainFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 8
        return f
    }()
}
