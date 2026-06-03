import Observation
import Foundation

/// Shared, in-memory Ромео Mobile state for the whole module (§7.3 — mock MVNO operator).
///
/// Mirrors the Cards module pattern: a `@MainActor @Observable` singleton, held via `@State` in each
/// screen, so an eSIM provisioned in the connect wizard, a roaming toggle, a credited cashback, or a
/// family allocation all reflect live across the hub and its sub-flows — without a shared view
/// ancestor (the routes are independent views pushed onto the hub's own `NavigationStack`). It
/// hydrates once per profile from the read-only ``APIClient``; every mutation below is a demo
/// simulation.
///
/// The tariff is **not** stored here — it is derived from the active profile's effective tier
/// (`AppSession.currentTier`) via ``MobileTariff/make(for:)``, so «тариф в связке с тиром» (§7.1)
/// holds with one source of truth. Changing tariff = changing tier (§4), done through
/// ``AppSession/setTier(_:for:)``; this store just reloads against the new tier.
@MainActor
@Observable
final class MobileStore {
    static let shared = MobileStore()

    private(set) var plan: MobilePlan?
    private(set) var baseTier: Tier = .base
    private(set) var accounts: [Account] = []
    private(set) var wallets: [CryptoWallet] = []
    private(set) var family: [FamilyShareMember] = []
    private(set) var payments: [MobilePayment] = []

    /// Roaming on/off. Defaults from the loaded plan; the unlimited (Infinite) tariff forces it on.
    var roamingEnabled: Bool = false

    private(set) var cashbackEarnedGb: Double = 0
    private(set) var cashbackCreditedGb: Double = 0

    private(set) var didLoad = false
    private(set) var loadFailed = false

    private var loadedProfileId: String?
    private var seq = 0

    private init() {}

    // MARK: - Load (once per profile)

    func load(api: any APIClient, profileId: String, force: Bool = false) async {
        guard !profileId.isEmpty, force || loadedProfileId != profileId else { return }
        do {
            // The plan is the essential fetch (nil = not connected → empty state, not an error).
            let p = try await api.mobilePlan(profileId: profileId)
            async let acctR  = (try? await api.accounts(profileId: profileId)) ?? []
            async let walletR = (try? await api.cryptoWallets(profileId: profileId)) ?? []
            async let subR   = (try? await api.subscription(profileId: profileId))?.tier

            let (a, w, tier) = await (acctR, walletR, subR)
            plan = p
            accounts = a
            wallets = w
            baseTier = tier ?? .base
            roamingEnabled = p?.roaming ?? false
            seedDerived(plan: p)
            loadFailed = false
            didLoad = true
            loadedProfileId = profileId          // commit only on success → a failed load can retry
        } catch {
            loadFailed = true
            didLoad = true
        }
    }

    /// Seed demo cashback + family from the plan (only when a plan exists).
    private func seedDerived(plan: MobilePlan?) {
        guard let plan else {
            cashbackEarnedGb = 0; cashbackCreditedGb = 0; family = []; payments = []
            return
        }
        cashbackEarnedGb = 4.2
        cashbackCreditedGb = 0
        family = [
            FamilyShareMember(id: "fm_me", name: "Вы", kind: .me, allocatedGb: 18, usedGb: plan.usedGb),
            FamilyShareMember(id: "fm_child", name: "Артём", kind: .child, allocatedGb: 8, usedGb: 5.1),
        ]
        payments = []
    }

    // MARK: - Derivations

    /// Mock usage detail derived from the plan (§7.2).
    func usage() -> MobileUsage {
        MobileUsage.mock(usedGb: plan?.usedGb ?? 0, usedMin: plan?.usedMin ?? 0)
    }

    /// Cashback view-model with the tier-linked accrual rate supplied by the caller (the hub knows the
    /// effective tariff).
    func cashback(rate: Double) -> MobileCashback {
        MobileCashback(earnedGb: cashbackEarnedGb, creditedGb: cashbackCreditedGb, perMonthGb: rate)
    }

    /// Bonus GB credited from cashback, added to the tariff cap.
    var bonusGb: Double { cashbackCreditedGb }

    /// Total shared GB across family members (§7.1 семейный пакет).
    var familyAllocatedGb: Double { family.reduce(0) { $0 + $1.allocatedGb } }
    var familyUsedGb: Double { family.reduce(0) { $0 + $1.usedGb } }

    /// All pay-from sources (fiat + цифр.₽ + crypto), crypto-first when `cryptoFirst` (роуминг, §7.1).
    func paymentSources(cryptoFirst: Bool = false) -> [PaymentSource] {
        let accs = accounts.map(PaymentSource.account)
        let wals = wallets.map(PaymentSource.wallet)
        return cryptoFirst ? (wals + accs) : (accs + wals)
    }

    // MARK: - Mutations · eSIM (§7.1)

    /// Provision an eSIM (mock operator): creates/refreshes the plan. New number / QR get a fresh
    /// MSISDN; MNP keeps the ported number. Used by the connect wizard's success step.
    @discardableResult
    func provisionESIM(method: ESIMMethod, profileId: String, portedNumber: String? = nil) -> MobilePlan {
        seq += 1
        let msisdn: String
        switch method {
        case .transfer:  msisdn = (portedNumber?.isEmpty == false) ? portedNumber! : "+7 999 765-43-21"
        case .qr:        msisdn = plan?.msisdn ?? "+7 999 100-20-\(String(format: "%02d", seq % 100))"
        case .newNumber: msisdn = "+7 999 700-\(String(format: "%02d", seq % 100))-77"
        }
        let new = MobilePlan(profileId: profileId, msisdn: msisdn, esimId: "esim_\(profileId)_\(seq)",
                             tariff: "M", dataGb: 30, minutes: 600, usedGb: 0, usedMin: 0, roaming: false)
        plan = new
        roamingEnabled = false
        seedDerived(plan: new)
        loadedProfileId = profileId
        didLoad = true
        return new
    }

    // MARK: - Mutations · roaming / cashback / family / payments

    func setRoaming(_ on: Bool) { roamingEnabled = on }

    /// Move accrued cashback GB into the package as bonus data (§7.1).
    func creditCashbackToPackage() {
        guard cashbackEarnedGb > 0 else { return }
        cashbackCreditedGb += cashbackEarnedGb
        cashbackEarnedGb = 0
    }

    func addFamilyMember(name: String, kind: FamilyShareMember.Kind, allocatedGb: Double) {
        seq += 1
        family.append(FamilyShareMember(id: "fm_\(seq)",
                                        name: name.isEmpty ? kind.label : name,
                                        kind: kind, allocatedGb: allocatedGb, usedGb: 0))
    }

    func allocateGb(_ gb: Double, memberId: String) {
        guard let i = family.firstIndex(where: { $0.id == memberId }) else { return }
        family[i].allocatedGb = max(0, gb)
    }

    @discardableResult
    func recordPayment(purpose: MobilePaymentPurpose, amount: Double, source: PaymentSource) -> MobilePayment {
        seq += 1
        let payment = MobilePayment(id: "mp_\(seq)", purpose: purpose, amount: amount,
                                    sourceTitle: source.title, isCrypto: source.isCrypto)
        payments.insert(payment, at: 0)
        // Topping up nudges cashback up a touch (demo feedback loop).
        if purpose == .topUp { cashbackEarnedGb += (amount / 10_000 * 10).rounded() / 10 }
        return payment
    }
}
