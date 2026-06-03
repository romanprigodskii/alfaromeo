import Foundation
import Observation

/// Feature-local shared state for «Выгода» (§9.3) — active cashback categories, the chosen
/// super-cashback category, and the accrued balance.
///
/// **Why a module-level shared store** (same rationale as `SavingsStore` / `HistoryStore`): the
/// ``APIClient`` is read-only fixtures and the Benefits destinations are pushed onto the *section*
/// `NavigationStack` (provided by `SectionScaffold`) with no module ancestor to inject into. A pure
/// in-memory `@MainActor @Observable` singleton lets the hub, the category picker, and the
/// super-cashback screen share one live selection. Selection is keyed per `profileId`, so switching
/// profiles is isolated. Every mutation is a demo simulation — there is no mutation API.
///
/// The per-profile dictionaries are normal (tracked) stored properties: the read-accessors below are
/// called inside view bodies, so Observation re-renders on every mutation (mirrors `SavingsStore`).
@MainActor
@Observable
final class BenefitsStore {
    static let shared = BenefitsStore()

    /// Accrued cashback (₽). Deterministic mock — not random, so screenshots are stable.
    private(set) var cashbackBalance: Double = 12_480.50
    /// Mock month-over-month delta (%) for the hub hero's «+X% больше, чем в прошлом месяце» line.
    let monthOverMonthDeltaPct: Double = 12

    /// Active cashback category IDs, per profile. Order-preserving so the at-limit eviction is FIFO.
    private var selectionByProfile: [String: [String]] = [:]
    /// The active super-cashback category ID, per profile (one at a time, Pro+ only).
    private var superByProfile: [String: String] = [:]

    private init() {
        // Seed a single category for the demo personal profile: valid at every tier (Base limit 1,
        // Pro limit 3, Infinite unlimited) so the slot meter never overflows after a tier change.
        selectionByProfile = [MockData.personalProfileId: ["cat_travel"]]
        superByProfile = [MockData.personalProfileId: "cat_travel"]
    }

    // MARK: - Tier → limits (derived from Entitlements — never hardcode a tier enum)

    /// How many categories may be active: 1 (basic) · 3 (raised) · unlimited (max / all categories).
    func categoryLimit(for e: Entitlements) -> Int {
        if e.allCashbackCategories { return .max }
        switch e.cashback {
        case .basic:  return 1
        case .raised: return 3
        case .max:    return .max
        }
    }

    /// Super-cashback is unlocked on Pro+ — i.e. anything above the basic cashback level. Reading the
    /// cashback level (not the tier) covers the business track (bizPro/bizCorp) automatically.
    func isSuperCashbackUnlocked(for e: Entitlements) -> Bool { e.cashback != .basic }

    // MARK: - Selection reads

    func selectedCategoryIds(profileId: String) -> [String] { selectionByProfile[profileId] ?? [] }
    func selectedCount(profileId: String) -> Int { selectedCategoryIds(profileId: profileId).count }
    func isSelected(_ id: String, profileId: String) -> Bool {
        selectedCategoryIds(profileId: profileId).contains(id)
    }
    func canSelectMore(profileId: String, entitlements e: Entitlements) -> Bool {
        selectedCount(profileId: profileId) < categoryLimit(for: e)
    }

    // MARK: - Selection mutations

    /// Toggle a category. Selecting while at the limit evicts the oldest (FIFO) — so the cap is never
    /// a dead end. Premium categories require `allCashbackCategories`; otherwise the toggle is a no-op.
    func toggleCategory(_ id: String, profileId: String, entitlements e: Entitlements) {
        guard let cat = CashbackCategory.lookup(id), !cat.premium || e.allCashbackCategories else { return }
        var ids = selectionByProfile[profileId] ?? []
        if let idx = ids.firstIndex(of: id) {
            ids.remove(at: idx)
        } else {
            let limit = categoryLimit(for: e)
            if limit != .max, ids.count >= limit, !ids.isEmpty { ids.removeFirst() }  // FIFO evict
            ids.append(id)
        }
        selectionByProfile[profileId] = ids
    }

    // MARK: - Super-cashback (§4 — повышенный кэшбек, Pro+)

    func superCashbackCategoryId(profileId: String) -> String? { superByProfile[profileId] }

    func hasSuperCashbackActive(profileId: String, entitlements e: Entitlements) -> Bool {
        isSuperCashbackUnlocked(for: e) && superByProfile[profileId] != nil
    }

    /// Set (or clear, with `nil`) the elevated category. No-op when super-cashback is locked.
    func setSuperCashbackCategory(_ id: String?, profileId: String, entitlements e: Entitlements) {
        guard isSuperCashbackUnlocked(for: e) else { return }
        if let id {
            superByProfile[profileId] = id
        } else {
            superByProfile.removeValue(forKey: profileId)
        }
    }
}
