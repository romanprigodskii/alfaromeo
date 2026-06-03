import Foundation

/// Mock usage detail (§7.2 «Детализация/использование») — by day and by category. Derived
/// deterministically from the plan's consumed GB/minutes so the breakdown matches the hub's remaining.
struct MobileUsageDay: Identifiable, Hashable, Sendable {
    let id: Int
    let label: String
    let gb: Double
    let minutes: Int
}

struct MobileUsageCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String
    let gb: Double
    var share: Double   // 0…1 of the period total
}

struct MobileUsage: Sendable {
    let days: [MobileUsageDay]
    let categories: [MobileUsageCategory]

    var totalGb: Double { days.reduce(0) { $0 + $1.gb } }
    var totalMinutes: Int { days.reduce(0) { $0 + $1.minutes } }
    var peakGb: Double { days.map(\.gb).max() ?? 0 }

    /// Deterministic 7-day + category split of the consumed GB/minutes.
    static func mock(usedGb: Double, usedMin: Int) -> MobileUsage {
        let dayLabels = ["6 дн", "5 дн", "4 дн", "3 дн", "2 дн", "Вчера", "Сегодня"]
        let weights: [Double] = [0.10, 0.14, 0.12, 0.18, 0.15, 0.16, 0.15]
        let days = dayLabels.indices.map { i in
            MobileUsageDay(id: i, label: dayLabels[i],
                           gb: (usedGb * weights[i] * 10).rounded() / 10,
                           minutes: Int((Double(usedMin) * weights[i]).rounded()))
        }
        let cats: [(String, String, Double)] = [
            ("Видео",       "play.rectangle.fill", 0.45),
            ("Соцсети",     "bubble.left.and.bubble.right.fill", 0.22),
            ("Мессенджеры", "message.fill", 0.12),
            ("Музыка",      "music.note", 0.11),
            ("Прочее",      "ellipsis.circle.fill", 0.10),
        ]
        let categories = cats.map { name, icon, share in
            MobileUsageCategory(id: name, name: name, icon: icon,
                                gb: (usedGb * share * 10).rounded() / 10, share: share)
        }
        return MobileUsage(days: days, categories: categories)
    }
}
