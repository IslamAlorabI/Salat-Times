
import Foundation

/// One day of prayer times as the server gave them, in the *city's* wall clock.
///
/// Times are stored as minutes since local midnight and are always **unadjusted**.
/// Per-prayer tuning is applied when the day is read (see `PrayerAdjustments`), so
/// changing an offset never invalidates cached data.
nonisolated struct DayTimings: Codable, Sendable, Equatable {
    /// `yyyy-MM-dd` in the city's time zone.
    let dateStamp: String
    /// `PrayerKey.rawValue` -> minutes since local midnight.
    let minutes: [String: Int]
    let hijri: HijriDate?

    func rawMinutes(for key: PrayerKey) -> Int? {
        minutes[key.rawValue]
    }

    /// Converts the API's `"HH:mm"` strings into minutes since local midnight.
    ///
    /// Aladhan currently returns a bare `HH:mm`, but it has historically appended a
    /// zone abbreviation (`"04:46 (EEST)"`), so only the leading clock is read and
    /// anything that doesn't parse to a real time is dropped rather than defaulted.
    static func parseMinutes(from timings: [String: String]) -> [String: Int] {
        var result: [String: Int] = [:]
        for key in PrayerKey.allCases {
            guard let raw = timings[key.rawValue] else { continue }
            let clock = raw.prefix { $0.isNumber || $0 == ":" }
            let parts = clock.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { continue }
            result[key.rawValue] = parts[0] * 60 + parts[1]
        }
        return result
    }
}

/// A set of days that share one time zone — the unit that gets cached to disk.
nonisolated struct PrayerTimetable: Codable, Sendable, Equatable {
    /// IANA identifier from the API's `meta.timezone`. Using this instead of the
    /// device's calendar is what makes a city in another zone count down correctly.
    var timeZoneID: String
    /// Keyed by `dateStamp`.
    var days: [String: DayTimings]

    static let empty = PrayerTimetable(timeZoneID: TimeZone.current.identifier, days: [:])

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    /// A Gregorian calendar pinned to the city's zone. Every date computation in the
    /// app goes through one of these, never through `Calendar.current`.
    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    mutating func merge(_ other: PrayerTimetable) {
        timeZoneID = other.timeZoneID
        days.merge(other.days) { _, new in new }
    }
}

nonisolated enum DateStamp {
    static func format(_ date: Date, in calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Midnight at the start of `stamp`, in the calendar's zone.
    static func startOfDay(_ stamp: String, in calendar: Calendar) -> Date? {
        let parts = stamp.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return calendar.date(from: c)
    }
}
