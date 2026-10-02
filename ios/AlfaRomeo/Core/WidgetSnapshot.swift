import Foundation
import WidgetKit

/// Снимок общего ₽-баланса для виджета на домашнем экране (`ios/AlfaRomeoWidget`).
///
/// «Главная» зовёт ``save(totalRub:)`` каждый раз, когда пересчитывает итог; виджет читает его из
/// App Group и пишет «обновлено HH:mm». Ключи продублированы в `AlfaRomeoWidget/WidgetData.swift`
/// (`WidgetShared`), потому что виджет не импортирует код приложения.
@MainActor
enum WidgetSnapshot {
    static let kind = "AlfaRomeoWidget"
    static let appGroup = "group.bank.alfa-romeo.demo"
    static let totalKey = "widget.balance.totalRub"
    static let updatedKey = "widget.balance.updatedAt"

    private static var lastReload: Date?

    static func save(totalRub: Double, now: Date = .now) {
        guard totalRub.isFinite, let defaults = UserDefaults(suiteName: appGroup) else { return }
        let previous = defaults.object(forKey: totalKey) as? Double
        defaults.set(totalRub, forKey: totalKey)
        defaults.set(now.timeIntervalSince1970, forKey: updatedKey)

        // Reload when the sum moved, or at most every 5 min so «обновлено» stays fresh.
        let changed = previous.map { abs($0 - totalRub) >= 0.01 } ?? true
        let stale = lastReload.map { now.timeIntervalSince($0) >= 300 } ?? true
        if changed || stale {
            lastReload = now
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
