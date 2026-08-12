import Foundation

// Standalone checks for PrayerScheduleCalculator. Compiled against the real Core
// sources with swiftc, since the project has no test target.

var failures = 0
var checks = 0

func check(_ label: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if condition {
        print("  ok   \(label)")
    } else {
        failures += 1
        print("  FAIL \(label) \(detail())")
    }
}

func iso(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    f.timeZone = TimeZone(identifier: "UTC")
    return f.string(from: date) + "Z"
}

func timetable(zone: String, days: [String: [PrayerKey: Int]]) -> PrayerTimetable {
    var built: [String: DayTimings] = [:]
    for (stamp, table) in days {
        var minutes: [String: Int] = [:]
        for (k, v) in table { minutes[k.rawValue] = v }
        built[stamp] = DayTimings(dateStamp: stamp, minutes: minutes, hijri: nil)
    }
    return PrayerTimetable(timeZoneID: zone, days: built)
}

func hm(_ h: Int, _ m: Int) -> Int { h * 60 + m }

var settings = PrayerSettings(
    cityRaw: "Cairo", latitude: 30.0444, longitude: 31.2357,
    method: 5, school: 0, latitudeAdjustment: 0, midnightMode: 0,
    tuneMinutes: [:], fajrBeforeSunriseMinutes: 0, ishaAfterMaghribMinutes: 0,
    language: "en", numberFormat: "western", use24Hour: true,
    reminderMinutes: 0, warningMinutes: 0)

func at(_ string: String, _ zone: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    f.timeZone = TimeZone(identifier: zone)
    return f.date(from: string)!
}

// ---------------------------------------------------------------------------
print("\n1. Times resolve in the city's zone, not the device's")
// Riyadh is UTC+3 year round. Dhuhr at 12:00 Riyadh == 09:00 UTC.
let riyadh = timetable(zone: "Asia/Riyadh", days: [
    "2026-08-12": [.fajr: hm(3, 50), .sunrise: hm(5, 20), .dhuhr: hm(12, 0),
                   .asr: hm(15, 30), .maghrib: hm(18, 40), .isha: hm(20, 10)],
])
let riyadhEvents = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "Asia/Riyadh"), timetable: riyadh, settings: settings)
let dhuhr = riyadhEvents.first { $0.key == .dhuhr }!
check("Dhuhr 12:00 Riyadh is 09:00 UTC", iso(dhuhr.date) == "2026-08-12 09:00:00Z", iso(dhuhr.date))

// The same wall clock in Cairo (UTC+3 in August, DST) must give a different instant
// than a zone-naive parse would.
let losAngeles = timetable(zone: "America/Los_Angeles", days: [
    "2026-08-12": [.fajr: hm(4, 45), .dhuhr: hm(12, 0), .isha: hm(20, 30)],
])
let laDhuhr = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "America/Los_Angeles"), timetable: losAngeles, settings: settings)
    .first { $0.key == .dhuhr }!
check("Dhuhr 12:00 Los Angeles is 19:00 UTC", iso(laDhuhr.date) == "2026-08-12 19:00:00Z", iso(laDhuhr.date))

// ---------------------------------------------------------------------------
print("\n2. Friday renames Dhuhr to Jumu'ah")
// 2026-08-14 is a Friday.
let friday = timetable(zone: "Africa/Cairo", days: [
    "2026-08-13": [.dhuhr: hm(13, 0)],
    "2026-08-14": [.dhuhr: hm(13, 0)],
])
let fridayEvents = PrayerScheduleCalculator.events(
    around: at("2026-08-14 10:00:00", "Africa/Cairo"), timetable: friday, settings: settings)
let fri = fridayEvents.first { $0.dateStamp == "2026-08-14" }!
let thu = fridayEvents.first { $0.dateStamp == "2026-08-13" }!
check("Friday Dhuhr -> prayer_jumuah", fri.translationKey == "prayer_jumuah", fri.translationKey)
check("Thursday Dhuhr -> prayer_dhuhr", thu.translationKey == "prayer_dhuhr", thu.translationKey)

// ---------------------------------------------------------------------------
print("\n3. Late evening rolls over to tomorrow's Fajr")
let rollover = timetable(zone: "Africa/Cairo", days: [
    "2026-08-12": [.fajr: hm(4, 46), .isha: hm(21, 3)],
    "2026-08-13": [.fajr: hm(4, 47), .isha: hm(21, 2)],
])
let lateNight = at("2026-08-12 23:30:00", "Africa/Cairo")
let rolloverEvents = PrayerScheduleCalculator.events(around: lateNight, timetable: rollover, settings: settings)
let nextAfterIsha = PrayerScheduleCalculator.next(after: lateNight, in: rolloverEvents)!
check("next at 23:30 is tomorrow's Fajr",
      nextAfterIsha.key == .fajr && nextAfterIsha.dateStamp == "2026-08-13",
      "\(nextAfterIsha.key) \(nextAfterIsha.dateStamp)")
check("current at 23:30 is today's Isha",
      PrayerScheduleCalculator.current(at: lateNight, in: rolloverEvents)?.dateStamp == "2026-08-12")

// ---------------------------------------------------------------------------
print("\n4. DST transition day")
// Europe/London switches GMT -> BST on 2026-03-29.
let london = timetable(zone: "Europe/London", days: [
    "2026-03-28": [.dhuhr: hm(13, 0)],
    "2026-03-29": [.dhuhr: hm(13, 0)],
])
let londonEvents = PrayerScheduleCalculator.events(
    around: at("2026-03-28 12:00:00", "Europe/London"), timetable: london, settings: settings)
let beforeDST = londonEvents.first { $0.dateStamp == "2026-03-28" }!
let afterDST = londonEvents.first { $0.dateStamp == "2026-03-29" }!
check("13:00 GMT on 28 Mar is 13:00 UTC", iso(beforeDST.date) == "2026-03-28 13:00:00Z", iso(beforeDST.date))
check("13:00 BST on 29 Mar is 12:00 UTC", iso(afterDST.date) == "2026-03-29 12:00:00Z", iso(afterDST.date))

// ---------------------------------------------------------------------------
print("\n5. Adjustments are applied on read")
var tuned = settings
tuned.tuneMinutes = [PrayerKey.fajr.rawValue: 5]
let base = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "Africa/Cairo"), timetable: rollover, settings: settings)
    .first { $0.key == .fajr }!
let shifted = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "Africa/Cairo"), timetable: rollover, settings: tuned)
    .first { $0.key == .fajr }!
check("+5 tune moves Fajr by exactly 300s",
      shifted.date.timeIntervalSince(base.date) == 300,
      "\(shifted.date.timeIntervalSince(base.date))")

var fixed = settings
fixed.fajrBeforeSunriseMinutes = 90
let withFixed = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "Asia/Riyadh"), timetable: riyadh, settings: fixed)
let fixedFajr = withFixed.first { $0.key == .fajr }!
let sunrise = withFixed.first { $0.key == .sunrise }!
check("fixed offset puts Fajr 90 min before sunrise",
      sunrise.date.timeIntervalSince(fixedFajr.date) == 90 * 60,
      "\(sunrise.date.timeIntervalSince(fixedFajr.date))")

// ---------------------------------------------------------------------------
print("\n6. Night markers are shown but never 'next'")
let withNight = timetable(zone: "Africa/Cairo", days: [
    "2026-08-12": [.isha: hm(21, 3), .midnight: hm(1, 0), .lastThird: hm(2, 47), .fajr: hm(4, 46)],
    "2026-08-13": [.isha: hm(21, 2), .midnight: hm(1, 0), .lastThird: hm(2, 47), .fajr: hm(4, 47)],
])
let nightNow = at("2026-08-12 21:30:00", "Africa/Cairo")
let nightEvents = PrayerScheduleCalculator.events(around: nightNow, timetable: withNight, settings: settings)
check("Midnight and Lastthird are present",
      nightEvents.contains { $0.key == .midnight } && nightEvents.contains { $0.key == .lastThird })
check("next after Isha skips night markers",
      PrayerScheduleCalculator.next(after: nightNow, in: nightEvents)?.key == .fajr,
      "\(String(describing: PrayerScheduleCalculator.next(after: nightNow, in: nightEvents)?.key))")
check("events come back sorted",
      nightEvents == nightEvents.sorted { $0.date < $1.date })

// ---------------------------------------------------------------------------
print("\n7. Countdown rounding")
check("7199s reads 1h 59m, never 1h 60m",
      Countdown(totalSeconds: 7199).hours == 1 && Countdown(totalSeconds: 7199).minutes == 59,
      "\(Countdown(totalSeconds: 7199).hours)h \(Countdown(totalSeconds: 7199).minutes)m")
check("3599s reads 0h 59m",
      Countdown(totalSeconds: 3599).hours == 0 && Countdown(totalSeconds: 3599).minutes == 59)
check("30s renders as <1m",
      Countdown(totalSeconds: 30).compactString(language: "en", numberFormat: "western") == "<1m",
      Countdown(totalSeconds: 30).compactString(language: "en", numberFormat: "western"))
check("negative remaining clamps to zero",
      Countdown(totalSeconds: -5).hours == 0 && Countdown(totalSeconds: -5).minutes == 0)
check("Arabic numerals apply to the compact form",
      Countdown(totalSeconds: 3 * 3600 + 12 * 60).compactString(language: "ar", numberFormat: "arabic") == "٣س ١٢د",
      Countdown(totalSeconds: 3 * 3600 + 12 * 60).compactString(language: "ar", numberFormat: "arabic"))

// ---------------------------------------------------------------------------
print("\n8. Malformed API times are skipped, not crashed on")
let parsed = DayTimings.parseMinutes(from: [
    "Fajr": "04:46",
    "Dhuhr": "13:00 (EEST)",     // historical Aladhan format
    "Asr": "garbage",
    "Maghrib": "25:99",
    "Isha": "21:03",
])
check("bare HH:mm parses", parsed["Fajr"] == 4 * 60 + 46)
check("zone suffix is tolerated", parsed["Dhuhr"] == 13 * 60, "\(String(describing: parsed["Dhuhr"]))")
check("garbage is dropped", parsed["Asr"] == nil)
check("out-of-range is dropped", parsed["Maghrib"] == nil)

// ---------------------------------------------------------------------------
print("\n9. Notification planning")

// A month of plausible days, so the horizon has something to reach into.
var monthDays: [String: [PrayerKey: Int]] = [:]
for day in 1...28 {
    monthDays[String(format: "2026-08-%02d", day)] = [
        .fajr: hm(4, 46), .sunrise: hm(6, 21), .dhuhr: hm(13, 0),
        .asr: hm(16, 38), .maghrib: hm(19, 39), .isha: hm(21, 3),
        .midnight: hm(1, 0), .lastThird: hm(2, 47),
    ]
}
let month = timetable(zone: "Africa/Cairo", days: monthDays)
let planNow = at("2026-08-05 08:00:00", "Africa/Cairo")

check("6 prayers with reminders fits a 5-day horizon",
      PrayerNotificationScheduler.horizonDays(enabledPrayers: 6, hasReminders: true) == 5,
      "\(PrayerNotificationScheduler.horizonDays(enabledPrayers: 6, hasReminders: true))")
check("6 prayers without reminders caps at 7 days",
      PrayerNotificationScheduler.horizonDays(enabledPrayers: 6, hasReminders: false) == 7)
check("a single prayer still caps at 7 days",
      PrayerNotificationScheduler.horizonDays(enabledPrayers: 1, hasReminders: false) == 7)

var reminding = settings
reminding.reminderMinutes = 15
func planned(_ s: PrayerSettings, enabled: Set<PrayerKey> = Set(PrayerKey.notifiable)) -> [PrayerNotificationScheduler.PlannedRequest] {
    PrayerNotificationScheduler.plan(now: planNow, timetable: month, settings: s,
                                     isEnabled: { enabled.contains($0) }, sound: { _ in nil })
}

let full = planned(reminding)
check("plan stays under the 64 pending-request cap", full.count <= 60, "\(full.count)")
check("every planned notification is in the future", full.allSatisfy { $0.date > planNow })
check("plan is sorted soonest-first", full.map(\.date) == full.map(\.date).sorted())
check("night markers are never scheduled",
      full.allSatisfy { !$0.identifier.contains("Midnight") && !$0.identifier.contains("Lastthird") })
check("identifiers are unique", Set(full.map(\.identifier)).count == full.count)

check("re-planning with identical settings is a no-op",
      Set(planned(reminding).map(\.identifier)) == Set(full.map(\.identifier)))

var otherReminder = reminding
otherReminder.reminderMinutes = 20
check("changing the reminder rotates every identifier",
      Set(planned(otherReminder).map(\.identifier)).isDisjoint(with: Set(full.map(\.identifier))))

var otherTune = reminding
otherTune.tuneMinutes = [PrayerKey.asr.rawValue: 2]
check("changing a tune rotates every identifier",
      Set(planned(otherTune).map(\.identifier)).isDisjoint(with: Set(full.map(\.identifier))))

var otherCity = reminding
otherCity.latitude = 24.7136
check("changing the city rotates every identifier",
      Set(planned(otherCity).map(\.identifier)).isDisjoint(with: Set(full.map(\.identifier))))

let fajrOnly = planned(reminding, enabled: [.fajr])
check("disabled prayers are excluded",
      fajrOnly.allSatisfy { $0.identifier.contains("_Fajr_") }, "\(fajrOnly.count)")
check("disabling prayers widens the horizon",
      fajrOnly.count > 7, "\(fajrOnly.count)")

check("no prayers enabled plans nothing", planned(reminding, enabled: []).isEmpty)


// ---------------------------------------------------------------------------
print("\n10. Fingerprints are stable across process launches")
// Swift.Hasher is seeded randomly per process. Using it for notification
// identifiers made every relaunch remove and re-add the entire schedule.
// These golden values fail loudly if a per-process hash is reintroduced.
check("StableHash is deterministic",
      StableHash.digest("salat") == "2ucikwhh1gttm",
      StableHash.digest("salat"))
check("StableHash separates similar inputs",
      StableHash.digest("a|0") != StableHash.digest("a|1"))

var fpA = settings
fpA.reminderMinutes = 15
let goldenFingerprint = "3jxmgvomwp1b5"
check("notificationFingerprint matches its golden value",
      fpA.notificationFingerprint == goldenFingerprint,
      fpA.notificationFingerprint)

var fpB = fpA
check("identical settings give identical fingerprints",
      fpA.notificationFingerprint == fpB.notificationFingerprint)
fpB.tuneMinutes = [PrayerKey.isha.rawValue: -3]
check("a tune change moves the fingerprint",
      fpA.notificationFingerprint != fpB.notificationFingerprint)


print("\n\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
