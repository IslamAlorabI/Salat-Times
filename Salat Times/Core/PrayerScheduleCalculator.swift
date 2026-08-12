
import Foundation

/// One prayer at one absolute instant.
nonisolated struct PrayerEvent: Sendable, Equatable, Identifiable {
    let key: PrayerKey
    /// The absolute instant, resolved in the city's time zone.
    let date: Date
    /// The civil day this event belongs to, in the city's zone.
    let dateStamp: String
    /// Already accounts for Jumu'ah, so callers never need to know about Fridays.
    let translationKey: String

    var id: String { "\(dateStamp)_\(key.rawValue)" }

    func name(language: String) -> String {
        Translations.string(translationKey, language: language)
    }
}

/// The single place in the app that turns a wall-clock string into a `Date`.
///
/// Everything downstream — the menu bar timer, the popover, the notification
/// scheduler, the monthly table — consumes `events(...)` rather than parsing times
/// itself. That is what keeps them from disagreeing.
nonisolated enum PrayerScheduleCalculator {

    /// All events for the civil days spanning `now`, from the previous day through two
    /// days ahead, sorted ascending.
    ///
    /// The window is what removes the old "if the time already passed, add a day" trick.
    /// Isha rolling into tomorrow's Fajr, the last third landing after midnight, and the
    /// date changing while the app is open all fall out of a sorted list of instants.
    static func events(around now: Date,
                       timetable: PrayerTimetable,
                       settings: PrayerSettings) -> [PrayerEvent] {
        events(dayOffsets: -1...2, from: now, timetable: timetable, settings: settings)
    }

    /// Events for a run of civil days relative to `date`, in the city's zone.
    /// The notification scheduler uses a wider range than the UI does.
    static func events(dayOffsets: ClosedRange<Int>,
                       from date: Date,
                       timetable: PrayerTimetable,
                       settings: PrayerSettings) -> [PrayerEvent] {
        let calendar = timetable.calendar
        var result: [PrayerEvent] = []

        for dayOffset in dayOffsets {
            guard let anchor = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let stamp = DateStamp.format(anchor, in: calendar)
            guard let day = timetable.days[stamp] else { continue }
            result.append(contentsOf: events(for: day, calendar: calendar, settings: settings))
        }

        return result.sorted { $0.date < $1.date }
    }

    /// Events for a single civil day. `Midnight` and `Lastthird` come from the API as
    /// wall-clock times after midnight, so they are attributed to the day they are
    /// listed under and land early in that day — which is correct: they belong to the
    /// night that *starts* on the previous evening.
    static func events(for day: DayTimings,
                       calendar: Calendar,
                       settings: PrayerSettings) -> [PrayerEvent] {
        guard let midnight = DateStamp.startOfDay(day.dateStamp, in: calendar) else { return [] }
        let isFriday = calendar.component(.weekday, from: midnight) == 6

        var events: [PrayerEvent] = []
        for key in PrayerKey.displayOrder {
            guard let raw = day.rawMinutes(for: key),
                  let adjusted = PrayerAdjustments.adjustedMinutes(for: key, in: day, settings: settings)
            else { continue }

            // Resolve the *unadjusted* wall clock through the calendar so that a DST
            // transition on this day is handled, then shift by the correction as a real
            // duration.
            guard let base = calendar.date(bySettingHour: (raw / 60) % 24,
                                           minute: raw % 60,
                                           second: 0,
                                           of: midnight) else { continue }
            let instant = base.addingTimeInterval(TimeInterval((adjusted - raw) * 60))

            events.append(PrayerEvent(key: key,
                                      date: instant,
                                      dateStamp: day.dateStamp,
                                      translationKey: key.translationKey(isFriday: isFriday)))
        }
        return events.sorted { $0.date < $1.date }
    }

    /// The next prayer strictly after `now`. Night markers are skipped — the countdown
    /// should never say "next: Midnight".
    static func next(after now: Date, in events: [PrayerEvent]) -> PrayerEvent? {
        events.first { $0.date > now && !$0.key.isNightMarker }
    }

    /// The most recent prayer at or before `now`, used to highlight the current period.
    static func current(at now: Date, in events: [PrayerEvent]) -> PrayerEvent? {
        events.last { $0.date <= now && !$0.key.isNightMarker }
    }

    /// The day `now` falls in, for the popover's list of today's times.
    static func day(containing now: Date, timetable: PrayerTimetable) -> DayTimings? {
        timetable.days[DateStamp.format(now, in: timetable.calendar)]
    }
}

/// Time remaining, with one rounding rule for the whole app.
///
/// The menu bar previously rounded minutes up while the popover rounded down, so the
/// two disagreed by a minute for most of every minute — and ceiling could produce
/// "1h 60m" in the last second of an hour. Both now floor.
nonisolated struct Countdown: Sendable, Equatable {
    let totalSeconds: Int

    var hours: Int { max(0, totalSeconds) / 3600 }
    var minutes: Int { (max(0, totalSeconds) % 3600) / 60 }
    var seconds: Int { max(0, totalSeconds) % 60 }

    static func from(_ now: Date, to event: PrayerEvent) -> Countdown {
        Countdown(totalSeconds: Int(event.date.timeIntervalSince(now).rounded(.down)))
    }

    /// The compact form shown in the menu bar, e.g. `3h 12m` / `٣س ١٢د`.
    func compactString(language: String, numberFormat: String) -> String {
        let hourSuffix: String
        let minuteSuffix: String
        switch language {
        case "ar", "ur", "fa": (hourSuffix, minuteSuffix) = ("س", "د")
        case "ru": (hourSuffix, minuteSuffix) = ("ч", "м")
        case "id": (hourSuffix, minuteSuffix) = ("j", "m")
        case "tr": (hourSuffix, minuteSuffix) = ("s", "d")
        default: (hourSuffix, minuteSuffix) = ("h", "m")
        }

        func localized(_ value: String) -> String {
            Translations.localizedNumber(value, numberFormat: numberFormat)
        }

        if hours > 0 {
            return "\(localized("\(hours)"))\(hourSuffix) \(localized("\(minutes)"))\(minuteSuffix)"
        }
        // Under a minute still deserves a reading rather than a bare "0m".
        let minuteText = (minutes == 0 && totalSeconds > 0) ? "<1" : "\(minutes)"
        return "\(localized(minuteText))\(minuteSuffix)"
    }
}
