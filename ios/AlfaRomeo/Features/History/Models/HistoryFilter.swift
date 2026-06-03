import Foundation

/// Feed filter state (§9.4: «фильтры — Пополнение / Списание / Даты / Счета»).
///
/// Transactions aren't yet linked to an `Account` in the contract, so the «Счета» filter resolves an
/// account *association* heuristically (``accountId(for:in:)``): crypto trades/converts → the crypto
/// account, everything else → the current account. The date presets are evaluated against a caller
/// supplied *reference* «now» (the newest transaction) so «30 дней / этот месяц» line up with the
/// 2035 fixtures instead of the real wall clock.
struct HistoryFilter: Equatable {
    enum Flow: String, CaseIterable, Identifiable, Hashable {
        case all, income, expense
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all:     return "Все"
            case .income:  return "Пополнения"
            case .expense: return "Списания"
            }
        }
    }

    enum DatePreset: String, CaseIterable, Identifiable, Hashable {
        case all, last30, thisMonth, lastMonth
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all:       return "Всё время"
            case .last30:    return "30 дней"
            case .thisMonth: return "Этот месяц"
            case .lastMonth: return "Прошлый месяц"
            }
        }
        /// Compact label for the chip when a preset is active.
        var chipLabel: String { self == .all ? "Даты" : title }
    }

    var flow: Flow = .all
    var accountId: String? = nil      // nil = все счета
    var datePreset: DatePreset = .all

    var isActive: Bool { flow != .all || accountId != nil || datePreset != .all }

    // MARK: - Matching

    /// Whether a transaction passes the current filter, given the profile's accounts and the feed's
    /// reference «now».
    func matches(_ tx: Transaction, accounts: [Account], reference: Date) -> Bool {
        switch flow {
        case .all:     break
        case .income:  if tx.amount < 0 { return false }
        case .expense: if tx.amount >= 0 { return false }
        }

        if let accountId, HistoryFilter.resolvedAccountId(for: tx, in: accounts) != accountId { return false }

        if datePreset != .all {
            guard let interval = datePreset.interval(reference: reference),
                  let date = HistoryFormatting.date(tx.createdAt),
                  interval.contains(date) else { return false }
        }
        return true
    }

    // MARK: - Account association (heuristic stand-in for a tx→account link)

    static func resolvedAccountId(for tx: Transaction, in accounts: [Account]) -> String? {
        let wantedType: AccountType = (tx.kind == .convert || tx.kind == .trade) ? .crypto : .current
        return accounts.first { $0.type == wantedType }?.id
            ?? accounts.first?.id
    }

    /// Accounts that actually have ≥1 matching transaction — drives the «Счета» menu so it never
    /// offers an account that would empty the feed.
    static func accountsWithActivity(_ accounts: [Account], transactions: [Transaction]) -> [Account] {
        let used = Set(transactions.compactMap { resolvedAccountId(for: $0, in: accounts) })
        return accounts.filter { used.contains($0.id) }
    }
}

extension HistoryFilter.DatePreset {
    /// Half-open interval the preset selects, relative to `reference`. `nil` for `.all`.
    func interval(reference: Date) -> DateInterval? {
        let cal = HistoryFormatting.calendar
        switch self {
        case .all:
            return nil
        case .last30:
            guard let start = cal.date(byAdding: .day, value: -30, to: reference) else { return nil }
            return DateInterval(start: start, end: reference)
        case .thisMonth:
            return cal.dateInterval(of: .month, for: reference)
        case .lastMonth:
            guard let prev = cal.date(byAdding: .month, value: -1, to: reference) else { return nil }
            return cal.dateInterval(of: .month, for: prev)
        }
    }
}
