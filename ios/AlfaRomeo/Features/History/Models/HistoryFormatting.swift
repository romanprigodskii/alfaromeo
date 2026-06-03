import Foundation

/// Date parsing + ru_RU formatting shared by the feed (group headers) and analytics (month nav).
///
/// All timestamps in the contract are ISO-8601 UTC (`…Z`), so grouping uses a UTC calendar — day and
/// month boundaries line up with the stored instants regardless of the device timezone (deterministic
/// demo). Relative «Сегодня / Вчера» labels are anchored to a caller-supplied *reference* date — the
/// feed passes the newest transaction's date so the 2035 fixtures read like a live feed.
enum HistoryFormatting {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return c
    }()

    private static let parser: ISO8601DateFormatter = ISO8601DateFormatter()

    private static func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        f.dateFormat = template
        return f
    }

    private static let dayMonthFmt   = formatter("d MMMM")
    private static let dayMonthYrFmt = formatter("d MMMM yyyy")
    private static let monthYearFmt  = formatter("LLLL yyyy")
    private static let monthShortFmt = formatter("LLL")
    private static let timeFmt       = formatter("HH:mm")

    /// Parse a contract ISO-8601 string into a `Date` (nil on malformed input).
    static func date(_ iso: String) -> Date? { parser.date(from: iso) }

    /// "2 июня"
    static func dayMonth(_ date: Date) -> String { dayMonthFmt.string(from: date) }

    /// "Июнь 2035"
    static func monthYear(_ date: Date) -> String { capitalizingFirst(monthYearFmt.string(from: date)) }

    /// "Июн." — compact month label for chart axes.
    static func monthShort(_ date: Date) -> String { capitalizingFirst(monthShortFmt.string(from: date)) }

    /// "09:14"
    static func time(_ date: Date) -> String { timeFmt.string(from: date) }

    /// Relative day header: «Сегодня» / «Вчера» / "2 июня" (with year only when it differs from the
    /// reference year, so an all-2035 feed stays terse).
    static func dayHeader(for day: Date, reference: Date) -> String {
        if calendar.isDate(day, inSameDayAs: reference) { return "Сегодня" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: reference),
           calendar.isDate(day, inSameDayAs: yesterday) { return "Вчера" }
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: reference)
        return (sameYear ? dayMonthFmt : dayMonthYrFmt).string(from: day)
    }

    private static func capitalizingFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
