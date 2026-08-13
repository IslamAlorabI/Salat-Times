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
    reminderMinutes: 0, warningMinutes: 0,
    enabledPrayers: Set(PrayerKey.notifiable.map(\.rawValue)), prayerSounds: [:])

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

// The popover's one-line reading. Padding only ever applies to the *trailing* units.
check("over an hour reads h:mm:ss with no leading zero",
      Countdown(totalSeconds: 2 * 3600 + 7 * 60 + 5).clockString(numberFormat: "western") == "2:07:05",
      Countdown(totalSeconds: 2 * 3600 + 7 * 60 + 5).clockString(numberFormat: "western"))
check("under an hour drops the hour field",
      Countdown(totalSeconds: 47 * 60 + 31).clockString(numberFormat: "western") == "47:31",
      Countdown(totalSeconds: 47 * 60 + 31).clockString(numberFormat: "western"))
check("the last seconds still read as a clock",
      Countdown(totalSeconds: 9).clockString(numberFormat: "western") == "0:09",
      Countdown(totalSeconds: 9).clockString(numberFormat: "western"))
check("clockString localizes its numerals",
      Countdown(totalSeconds: 3600).clockString(numberFormat: "arabic") == "١:٠٠:٠٠",
      Countdown(totalSeconds: 3600).clockString(numberFormat: "arabic"))

// ---------------------------------------------------------------------------
print("\n7b. Countdown progress")
let progressDay = timetable(zone: "Africa/Cairo", days: [
    "2026-08-12": [.fajr: hm(4, 0), .sunrise: hm(6, 0), .dhuhr: hm(12, 0),
                   .asr: hm(16, 0), .maghrib: hm(19, 0), .isha: hm(21, 0)],
])
let progressEvents = PrayerScheduleCalculator.events(
    around: at("2026-08-12 10:00:00", "Africa/Cairo"), timetable: progressDay, settings: settings)
check("halfway between two prayers reads 0.5",
      PrayerScheduleCalculator.progress(at: at("2026-08-12 09:00:00", "Africa/Cairo"),
                                        in: progressEvents).map { abs($0 - 0.5) < 0.001 } == true,
      "\(String(describing: PrayerScheduleCalculator.progress(at: at("2026-08-12 09:00:00", "Africa/Cairo"), in: progressEvents)))")
check("progress never leaves 0...1",
      [at("2026-08-12 06:00:01", "Africa/Cairo"), at("2026-08-12 11:59:59", "Africa/Cairo")]
          .allSatisfy { (PrayerScheduleCalculator.progress(at: $0, in: progressEvents) ?? -1) >= 0
                     && (PrayerScheduleCalculator.progress(at: $0, in: progressEvents) ?? 2) <= 1 })

// Oslo in June really does return Fajr 01:17 / Isha 01:18. A zero-length interval must
// not become a division by zero for the progress bar to render.
let degenerate = timetable(zone: "Europe/Oslo", days: [
    "2026-06-15": [.isha: hm(1, 17), .fajr: hm(1, 17), .sunrise: hm(3, 53), .dhuhr: hm(13, 21)],
])
let degenerateEvents = PrayerScheduleCalculator.events(
    around: at("2026-06-15 02:00:00", "Europe/Oslo"), timetable: degenerate, settings: settings)
check("a zero-length night yields no progress rather than infinity",
      PrayerScheduleCalculator.progress(at: at("2026-06-15 01:17:00", "Europe/Oslo"),
                                        in: degenerateEvents).map(\.isFinite) != false)
check("progress is nil when nothing precedes now",
      PrayerScheduleCalculator.progress(at: at("2026-08-12 00:30:00", "Africa/Cairo"),
                                        in: progressEvents) == nil)

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

// A request's sound is fixed when it is added, so a sound change has to rotate the
// identifier or the already-pending alert keeps playing the old one — the reconciler
// sees a matching id and does nothing.
var otherSound = reminding
otherSound.prayerSounds = [PrayerKey.fajr.rawValue: "Glass"]
check("changing a sound rotates every identifier",
      Set(planned(otherSound).map(\.identifier)).isDisjoint(with: Set(full.map(\.identifier))))

// Enabling is handled by the set difference instead, so it must *not* rotate: folding
// it in would rewrite every other prayer's pending requests for nothing.
// Enabling is handled by the set difference instead, so it must *not* rotate: folding
// it in would rewrite every other prayer's pending requests for nothing.
var otherEnabled = reminding
otherEnabled.enabledPrayers = [PrayerKey.fajr.rawValue]
check("toggling a prayer does not rotate identifiers",
      otherEnabled.notificationFingerprint == reminding.notificationFingerprint)

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
// Re-pin this only when the fingerprint's *inputs* deliberately change. It last moved on
// 2026-08-13, when `notificationContentVersion` joined them so that bumping the content
// shape rotates every identifier once and rebuilds the already-pending requests; before
// that it moved when per-prayer sounds joined them. A change here that you did *not*
// intend means something reintroduced a per-process hash.
let goldenFingerprint = "1pziikkwure5n"
check("notificationFingerprint matches its golden value",
      fpA.notificationFingerprint == goldenFingerprint,
      fpA.notificationFingerprint)

var fpB = fpA
check("identical settings give identical fingerprints",
      fpA.notificationFingerprint == fpB.notificationFingerprint)
fpB.tuneMinutes = [PrayerKey.isha.rawValue: -3]
check("a tune change moves the fingerprint",
      fpA.notificationFingerprint != fpB.notificationFingerprint)


// ---------------------------------------------------------------------------
print("\n11. Settings are clamped on read, not trusted from the store")
// These keys are written by the settings window today and by a widget later, and an
// out-of-range value would otherwise go straight into a request URL or an instant.
let store = UserDefaults(suiteName: "salat-times-checks")!
for key in store.dictionaryRepresentation().keys { store.removeObject(forKey: key) }

store.set(999, forKey: "tune_Fajr")
store.set(-999, forKey: "tune_Isha")
store.set(7, forKey: "asrSchool")
store.set(42, forKey: "latitudeAdjustment")
store.set(3, forKey: "midnightMode")
store.set(6, forKey: "fajrBeforeSunriseMinutes")
store.set(9999, forKey: "ishaAfterMaghribMinutes")

let loaded = PrayerSettings.load(from: store)
check("tune clamps to +30", loaded.tuneMinutes[PrayerKey.fajr.rawValue] == 30,
      "\(String(describing: loaded.tuneMinutes[PrayerKey.fajr.rawValue]))")
check("tune clamps to -30", loaded.tuneMinutes[PrayerKey.isha.rawValue] == -30,
      "\(String(describing: loaded.tuneMinutes[PrayerKey.isha.rawValue]))")
check("school clamps to 0...1", loaded.school == 1, "\(loaded.school)")
check("latitude rule clamps to 0...3", loaded.latitudeAdjustment == 3, "\(loaded.latitudeAdjustment)")
check("midnight mode clamps to 0...1", loaded.midnightMode == 1, "\(loaded.midnightMode)")
check("a too-small fixed offset clamps up to 15",
      loaded.fajrBeforeSunriseMinutes == 15, "\(loaded.fajrBeforeSunriseMinutes)")
check("a too-large fixed offset clamps down to 180",
      loaded.ishaAfterMaghribMinutes == 180, "\(loaded.ishaAfterMaghribMinutes)")

// Notifications have always been opt-out; an absent key must not read as "off".
check("an unset prayer defaults to notifying",
      loaded.enabledPrayers == Set(PrayerKey.notifiable.map(\.rawValue)),
      "\(loaded.enabledPrayers.sorted())")
store.set(false, forKey: "notification_Sunrise_enabled")
store.set("Glass", forKey: "notification_Fajr_sound")
let reloaded = PrayerSettings.load(from: store)
check("a disabled prayer drops out of the snapshot",
      !reloaded.enabledPrayers.contains(PrayerKey.sunrise.rawValue))
check("sounds come through the snapshot",
      reloaded.prayerSounds[PrayerKey.fajr.rawValue] == "Glass",
      "\(String(describing: reloaded.prayerSounds[PrayerKey.fajr.rawValue]))")
check("a fixed offset of 0 stays off — 0 means disabled, not 15",
      PrayerSettings.load(from: UserDefaults(suiteName: "salat-times-checks-empty")!)
          .fajrBeforeSunriseMinutes == 0)

for key in store.dictionaryRepresentation().keys { store.removeObject(forKey: key) }


// ---------------------------------------------------------------------------
print("\n12. Every string carries all eight languages")
// A missing language falls back to English and then to the raw key, silently — so a
// half-translated key looks fine in English and ships broken everywhere else.
let languages = ["ar", "en", "ru", "id", "tr", "ur", "fa", "de"]
let tables: [(String, [String: [String: String]])] = [
    ("uiStrings", uiStrings),
    ("methodStrings", methodStrings),
    ("prayerStrings", prayerStrings),
    ("hijriStrings", hijriStrings),
    ("settingsStrings", settingsStrings),
]

// Deliberately blank outside Arabic: "عام ١٤٤٨" reads naturally, "year 1448" does not,
// so the label simply does not exist in the other seven. Present but empty is the honest
// encoding of that — the key still resolves rather than falling through to its own name.
let intentionallyBlank: Set<String> = ["hijri_year_label", "hijri_migration_suffix"]

var incomplete: [String] = []
var blank: [String] = []
var totalKeys = 0
for (table, entries) in tables {
    for (key, values) in entries {
        totalKeys += 1
        let missing = languages.filter { values[$0] == nil }
        if !missing.isEmpty {
            incomplete.append("\(table).\(key) missing \(missing.sorted().joined(separator: ","))")
        }
        if !intentionallyBlank.contains(key),
           values.contains(where: { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }) {
            blank.append("\(table).\(key)")
        }
    }
}

check("no key is missing a language",
      incomplete.isEmpty,
      "\(incomplete.count): \(incomplete.sorted().prefix(5).joined(separator: "; "))")
check("no translation is blank", blank.isEmpty, blank.sorted().prefix(5).joined(separator: "; "))
check("the tables are non-trivial", totalKeys > 150, "\(totalKeys)")

// Keys the code looks up by literal have no compiler to catch a typo.
let requiredKeys = [
    "general", "prayer_times", "appearance", "about", "prayer_notifications",
    "startup", "timing", "interface_language", "refresh_data_hint",
    "calculation_options", "calculation_options_hint",
    "menu_bar_panel", "translucency", "translucency_off", "translucency_subtle",
    "translucency_medium", "translucency_full", "translucency_hint",
    "show_night_times", "show_night_times_hint",
    "app_name", "about_tagline", "about_details", "about_version",
    "about_requires", "about_links", "about_data_source",
    "about_data_note", "about_developer",
    "monthly_schedule", "schedule_date", "export", "export_csv", "export_pdf", "export_png", "print", "schedule_footnote",
    "asr_madhab", "high_latitude", "midnight_mode", "prayer_tuning", "fixed_times",
    "location_source", "location_choose_city", "location_use_device", "location_detect_now",
    "location_detecting", "location_not_detected", "location_failed", "location_denied",
    "location_open_settings", "location_follow", "location_follow_hint", "location_updated",
    "location_approximate", "location_approximate_short",
    "widget_needs_app", "widget_next_prayer", "widget_next_prayer_hint",
    "widget_today", "widget_today_hint",
]
let unresolved = requiredKeys.filter { Translations.string($0, language: "de") == $0 }
check("every key the UI asks for resolves", unresolved.isEmpty, unresolved.joined(separator: ", "))


// ---------------------------------------------------------------------------
print("\n13. A detected location survives the round trip through the store")
let locationStore = UserDefaults(suiteName: "salat-times-checks-location")!
for key in locationStore.dictionaryRepresentation().keys { locationStore.removeObject(forKey: key) }

// Rounding is not cosmetic: the fingerprint keys the month cache, so an unrounded fix
// would mint a new cache file and a new request every time GPS wobbled a few metres.
let jittery = DeviceLocation(latitude: 64.146612, longitude: -21.942503)
check("coordinates round to ~1 km",
      jittery.latitude == 64.15 && jittery.longitude == -21.94,
      "\(jittery.latitude), \(jittery.longitude)")
let jitteredAgain = DeviceLocation(latitude: 64.145901, longitude: -21.943104)
check("a few metres of drift is the same place", jittery.isSamePlace(as: jitteredAgain))
check("a kilometre away is not",
      !jittery.isSamePlace(as: DeviceLocation(latitude: 64.17, longitude: -21.94)))

check("an out-of-range coordinate is rejected",
      !DeviceLocation.isValid(latitude: 91, longitude: 0))
check("(0, 0) is a real place, not 'unset'",
      DeviceLocation.isValid(latitude: 0, longitude: 0))

// A fix with no name still has to label a popover, a printed sheet and a file name.
check("an unnamed fix falls back to its coordinates",
      DeviceLocation(latitude: -33.92, longitude: 18.42).displayName == "33.92S, 18.42E",
      DeviceLocation(latitude: -33.92, longitude: 18.42).displayName)

DeviceLocation(latitude: 51.5074, longitude: -0.1278,
               placeName: "London", countryCode: "GB").save(to: locationStore)
let restored = DeviceLocation.load(from: locationStore)
check("a saved fix loads back", restored?.placeName == "London" && restored?.countryCode == "GB")
check("a real fix is not flagged approximate", restored?.isApproximate == false)

// An IP-derived location can be tens of kilometres from the machine, which is worth
// minutes of prayer time. The flag is what stops that being invisible.
DeviceLocation(latitude: 35.6895, longitude: 139.6917,
               placeName: "Tokyo", countryCode: "JP", isApproximate: true).save(to: locationStore)
check("an approximate fix stays flagged through the store",
      DeviceLocation.load(from: locationStore)?.isApproximate == true)
DeviceLocation(latitude: 59.9139, longitude: 10.7522,
               placeName: "Oslo", countryCode: "NO").save(to: locationStore)
check("a later real fix clears the flag",
      DeviceLocation.load(from: locationStore)?.isApproximate == false)
check("an empty store has no fix",
      DeviceLocation.load(from: UserDefaults(suiteName: "salat-times-checks-empty")!) == nil)

// ---------------------------------------------------------------------------
print("\n14. Device location reaches PrayerSettings, and falls back when it cannot")
// Saved here rather than relied on from the section above, so this section can be read —
// and moved — on its own.
DeviceLocation(latitude: 51.5074, longitude: -0.1278,
               placeName: "London", countryCode: "GB").save(to: locationStore)
locationStore.set("Cairo", forKey: "selectedCityRaw")
check("the mode is off by default, so the picked city wins",
      PrayerSettings.load(from: locationStore).latitude == City.cairo.coordinates.latitude)

locationStore.set(LocationMode.device.rawValue, forKey: DeviceLocation.Keys.mode)
let following = PrayerSettings.load(from: locationStore)
check("switching to device mode uses the fix", following.latitude == 51.51, "\(following.latitude)")
check("the place name labels the settings", following.cityRaw == "London", following.cityRaw)
check("the snapshot knows it is not on a listed city", following.usesCustomCoordinates)
check("moving changes the request fingerprint, so the month is refetched",
      following.requestFingerprint != PrayerSettings.load(from: UserDefaults(suiteName: "salat-times-checks-empty")!).requestFingerprint)

// Turning the mode on before the first fix must not leave the app with no location at all.
locationStore.removeObject(forKey: LocationKeys.device.latitude)
locationStore.removeObject(forKey: LocationKeys.device.longitude)
let noFixYet = PrayerSettings.load(from: locationStore)
check("device mode with no fix falls back to the picked city",
      noFixYet.latitude == City.cairo.coordinates.latitude && !noFixYet.usesCustomCoordinates,
      "\(noFixYet.latitude)")

// A hand-edited or corrupted coordinate must never reach a request URL.
locationStore.set(999.0, forKey: LocationKeys.device.latitude)
locationStore.set(0.0, forKey: LocationKeys.device.longitude)
check("a corrupt stored coordinate falls back too",
      PrayerSettings.load(from: locationStore).latitude == City.cairo.coordinates.latitude)

for key in locationStore.dictionaryRepresentation().keys { locationStore.removeObject(forKey: key) }

// ---------------------------------------------------------------------------
print("\n14b. A hand-picked point is a third source, stored apart from the detected fix")
// The two must not share keys: re-detecting would otherwise overwrite a point the user
// deliberately dropped on the map, and switching modes back and forth would lose one.
locationStore.set("Cairo", forKey: "selectedCityRaw")
DeviceLocation(latitude: 51.5074, longitude: -0.1278,
               placeName: "London", countryCode: "GB").save(to: locationStore, keys: .device)
DeviceLocation(latitude: 35.6895, longitude: 139.6917,
               placeName: "Tokyo", countryCode: "JP").save(to: locationStore, keys: .manual)

locationStore.set(LocationMode.manual.rawValue, forKey: DeviceLocation.Keys.mode)
let pinned = PrayerSettings.load(from: locationStore)
check("manual mode uses the pin, not the fix and not the city",
      pinned.latitude == 35.69 && pinned.cityRaw == "Tokyo",
      "\(pinned.latitude) \(pinned.cityRaw)")
check("the pin counts as custom coordinates", pinned.usesCustomCoordinates)

locationStore.set(LocationMode.device.rawValue, forKey: DeviceLocation.Keys.mode)
check("switching back to the device still finds its own fix",
      PrayerSettings.load(from: locationStore).cityRaw == "London")
locationStore.set(LocationMode.manual.rawValue, forKey: DeviceLocation.Keys.mode)
check("and the pin survived the round trip",
      PrayerSettings.load(from: locationStore).cityRaw == "Tokyo")

// The map picker writes the pin *before* anything reads it, but a mode set with no pin —
// or a pin edited by hand into nonsense — must still leave the app somewhere real.
locationStore.removeObject(forKey: LocationKeys.manual.latitude)
locationStore.removeObject(forKey: LocationKeys.manual.longitude)
check("manual mode with no pin falls back to the picked city",
      PrayerSettings.load(from: locationStore).latitude == City.cairo.coordinates.latitude)
locationStore.set(12.0, forKey: LocationKeys.manual.latitude)
locationStore.set(-999.0, forKey: LocationKeys.manual.longitude)
check("a corrupt pin falls back too",
      PrayerSettings.load(from: locationStore).latitude == City.cairo.coordinates.latitude)

// An unknown mode written by a future build must not leave anyone without prayer times.
locationStore.set("satellite-uplink", forKey: DeviceLocation.Keys.mode)
check("an unrecognised mode reads as the city list",
      LocationMode.from("satellite-uplink") == .city
          && PrayerSettings.load(from: locationStore).latitude == City.cairo.coordinates.latitude)

for key in locationStore.dictionaryRepresentation().keys { locationStore.removeObject(forKey: key) }

// ---------------------------------------------------------------------------
print("\n15. The nearest listed city is what suggests a method")
check("a listed city finds itself",
      City.nearest(toLatitude: 59.9139, longitude: 10.7522) == .oslo,
      City.nearest(toLatitude: 59.9139, longitude: 10.7522).rawValue)
check("a coordinate in Saudi Arabia lands on a Saudi city",
      City.recommendedMethod(forLatitude: 21.42, longitude: 39.83) == 4,
      "\(City.recommendedMethod(forLatitude: 21.42, longitude: 39.83))")
check("a coordinate in Turkey gets Diyanet",
      City.recommendedMethod(forLatitude: 41.01, longitude: 28.98) == 13,
      "\(City.recommendedMethod(forLatitude: 41.01, longitude: 28.98))")
// Longitude wrapping is where a naive distance goes wrong.
check("the Pacific does not fold the world in half",
      City.nearest(toLatitude: 35.68, longitude: 139.69) == .tokyo,
      City.nearest(toLatitude: 35.68, longitude: 139.69).rawValue)


// ---------------------------------------------------------------------------
print("\n16. Delivered notifications expire instead of piling up")
// Notification Center keeps everything it has ever shown until the user clears it, so six
// alerts a day becomes a wall of them. The rule: a reminder dies when its prayer arrives,
// a prayer's alert dies when the next prayer arrives.
let asr = at("2026-08-13 16:40:00", "Africa/Cairo")
let maghrib = at("2026-08-13 19:41:00", "Africa/Cairo")
let asrReminder = asr.addingTimeInterval(-15 * 60)

let inbox: [(identifier: String, date: Date)] = [
    ("reminder_Asr_2026-08-13_abc", asrReminder),
    ("prayer_Asr_2026-08-13_abc", asr),
]

// Between the reminder and Asr, both belong: the reminder is why the user looks.
let beforeAsr = PrayerNotificationScheduler.staleDelivered(
    inbox.filter { $0.date <= asrReminder }, now: asrReminder.addingTimeInterval(60),
    currentPrayer: at("2026-08-13 13:01:00", "Africa/Cairo"))
check("a reminder survives until its prayer arrives", beforeAsr.isEmpty, "\(beforeAsr)")

// The moment Asr arrives, its reminder is replaced by the prayer's own alert.
let atAsr = PrayerNotificationScheduler.staleDelivered(inbox, now: asr, currentPrayer: asr)
check("the reminder goes when the prayer arrives", atAsr == ["reminder_Asr_2026-08-13_abc"], "\(atAsr)")
check("the prayer's own alert stays", !atAsr.contains("prayer_Asr_2026-08-13_abc"))

// And Asr's alert goes when Maghrib arrives, so at most two are ever on screen.
let atMaghrib = PrayerNotificationScheduler.staleDelivered(inbox, now: maghrib, currentPrayer: maghrib)
check("the previous prayer's alert goes at the next prayer", atMaghrib.count == 2, "\(atMaghrib)")

// A clock that jumps forward and back fires everything at once, stamped in the future.
// Those never become "old", so they would sit there for ever.
let bogus: [(identifier: String, date: Date)] = [("prayer_Fajr_2038-08-19_abc",
                                                  at("2038-08-19 08:19:00", "Africa/Cairo"))]
let jumped = PrayerNotificationScheduler.staleDelivered(bogus, now: asr, currentPrayer: asr)
check("a future-dated delivery is swept too", jumped.count == 1, "\(jumped)")

// A notification stamped a second or two after its trigger is not "from the future".
let justNow: [(identifier: String, date: Date)] = [("prayer_Asr_2026-08-13_abc", asr.addingTimeInterval(2))]
check("a delivery a moment after its instant is kept",
      PrayerNotificationScheduler.staleDelivered(justNow, now: asr, currentPrayer: asr).isEmpty)

// With no schedule to measure against, fall back to an age limit rather than keeping for ever.
let old: [(identifier: String, date: Date)] = [("prayer_Isha_2026-08-12_abc", asr.addingTimeInterval(-7200))]
check("with no schedule, old deliveries still expire",
      PrayerNotificationScheduler.staleDelivered(old, now: asr, currentPrayer: nil).count == 1)
check("with no schedule, recent deliveries are kept",
      PrayerNotificationScheduler.staleDelivered(
        [("prayer_Isha_2026-08-13_abc", asr.addingTimeInterval(-60))], now: asr, currentPrayer: nil).isEmpty)


// ---------------------------------------------------------------------------
print("\n17. Settings survive the move into the App Group container")
// The widget runs in its own sandbox and cannot see the app's `UserDefaults.standard`, so
// everything moves to a shared suite. Getting this wrong looks like a fresh install to
// someone who has spent time setting the app up, so it is worth pinning down.
let legacy = UserDefaults(suiteName: "salat-times-checks-legacy")!
let shared = UserDefaults(suiteName: "salat-times-checks-shared")!
for store in [legacy, shared] {
    for key in store.dictionaryRepresentation().keys { store.removeObject(forKey: key) }
}

check("app keys are recognised", SharedStore.isOwned("appLanguage"))
check("per-prayer keys are recognised by prefix",
      SharedStore.isOwned("tune_Fajr") && SharedStore.isOwned("notification_Isha_sound"))
// Both stored coordinates, not just the detected one — a pin left behind in the old suite
// would come back as an empty custom location on the next launch.
check("location keys are recognised",
      SharedStore.isOwned(DeviceLocation.Keys.mode)
          && SharedStore.isOwned(LocationKeys.device.latitude)
          && SharedStore.isOwned(LocationKeys.manual.latitude)
          && SharedStore.isOwned(LocationKeys.manual.placeName))
// UserDefaults is full of things AppKit and the system put there; copying those into a
// shared suite would be both rude and unpredictable.
check("system keys are left alone",
      !SharedStore.isOwned("NSNavLastRootDirectory") && !SharedStore.isOwned("com.apple.trackpad.scaling"))

legacy.set("ar", forKey: "appLanguage")
legacy.set("Oslo", forKey: "selectedCityRaw")
legacy.set(7, forKey: "tune_Fajr")
legacy.set(false, forKey: "notification_Sunrise_enabled")
legacy.set("/Users/someone/Downloads", forKey: "NSNavLastRootDirectory")

let copied = SharedStore.migrateIfNeeded(from: legacy, to: shared)
check("the settings came across", copied == 4, "\(copied)")
check("the language came across", shared.string(forKey: "appLanguage") == "ar")
check("a per-prayer tune came across", shared.integer(forKey: "tune_Fajr") == 7)
check("an opt-out came across", shared.object(forKey: "notification_Sunrise_enabled") as? Bool == false)
check("a system key did not", shared.object(forKey: "NSNavLastRootDirectory") == nil)
// The old values stay put, so a build without the entitlement still finds them.
check("the source is left intact", legacy.string(forKey: "appLanguage") == "ar")

// Running on every launch must be a no-op after the first, or a later change would be
// silently reverted to whatever the old store still held.
shared.set("en", forKey: "appLanguage")
check("a second run copies nothing", SharedStore.migrateIfNeeded(from: legacy, to: shared) == 0)
check("a change made after migrating survives it",
      shared.string(forKey: "appLanguage") == "en", shared.string(forKey: "appLanguage") ?? "nil")

// Same store both sides — the no-group fallback — must not loop back on itself.
check("migrating a store into itself does nothing",
      SharedStore.migrateIfNeeded(from: legacy, to: legacy) == 0)

for store in [legacy, shared] {
    for key in store.dictionaryRepresentation().keys { store.removeObject(forKey: key) }
}


print("\n\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
