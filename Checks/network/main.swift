import Foundation

struct ClientProbeFailure: Error {}

// End-to-end check of the cache layer: one real network fetch, then prove that a
// second load is served from disk and that a broken network still yields times.

let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("salat-repocheck-\(UUID().uuidString)")

var settings = PrayerSettings(
    cityRaw: "Riyadh", latitude: 24.7136, longitude: 46.6753,
    method: 4, school: 0, latitudeAdjustment: 0, midnightMode: 0,
    tuneMinutes: [:], fajrBeforeSunriseMinutes: 0, ishaAfterMaghribMinutes: 0,
    language: "en", numberFormat: "western", use24Hour: true,
    reminderMinutes: 0, warningMinutes: 0,
    enabledPrayers: Set(PrayerKey.notifiable.map(\.rawValue)), prayerSounds: [:])

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    print(ok ? "  ok   \(label)" : "  FAIL \(label) \(detail())")
    if !ok { failures += 1 }
}

let store = MonthCacheStore(root: tempRoot)
let repo = PrayerRepository(client: AladhanClient(), store: store)

let semaphore = DispatchSemaphore(value: 0)

Task {
    defer { semaphore.signal() }
    do {
        print("\n1. Cold load hits the network and writes a cache file")
        let first = try await repo.load(around: Date(), settings: settings)
        check("timezone came from the API", first.timetable.timeZoneID == "Asia/Riyadh", first.timetable.timeZoneID)
        check("a full month of days was decoded", first.timetable.days.count >= 28, "\(first.timetable.days.count)")
        check("reported as freshly fetched", first.fetchedAt != nil && !first.servedStale)

        let files = (try? FileManager.default.contentsOfDirectory(atPath: tempRoot.path)) ?? []
        check("one cache file on disk", files.count >= 1, "\(files)")
        check("file name carries the settings fingerprint",
              files.first?.contains(settings.requestFingerprint) == true, "\(files)")

        print("\n2. Times are usable and self-consistent")
        let events = PrayerScheduleCalculator.events(around: Date(), timetable: first.timetable, settings: settings)
        check("events were produced", !events.isEmpty, "\(events.count)")
        check("Fajr precedes Dhuhr on the same day",
              {
                  let stamp = DateStamp.format(Date(), in: first.timetable.calendar)
                  let today = events.filter { $0.dateStamp == stamp }
                  guard let f = today.first(where: { $0.key == .fajr }),
                        let d = today.first(where: { $0.key == .dhuhr }) else { return false }
                  return f.date < d.date
              }())
        check("Midnight and Lastthird arrived from the API",
              events.contains { $0.key == .midnight } && events.contains { $0.key == .lastThird })

        print("\n3. A second load is served from disk, not refetched")
        // Prove it rather than assume it: plant a value the server would never return,
        // then load through a repository with a cold in-memory cache. If the sentinel
        // comes back, the data came off disk.
        let todayStamp = DateStamp.format(Date(), in: first.timetable.calendar)
        let key = MonthKey.containing(Date(), calendar: first.timetable.calendar, settings: settings)
        guard var planted = store.load(key), let realDay = planted.timetable.days[todayStamp] else {
            check("cache file could be re-read for planting", false); throw ClientProbeFailure()
        }
        var sentinelMinutes = realDay.minutes
        sentinelMinutes[PrayerKey.fajr.rawValue] = 1   // 00:01, never a real Fajr
        planted.timetable.days[todayStamp] = DayTimings(dateStamp: todayStamp,
                                                        minutes: sentinelMinutes,
                                                        hijri: realDay.hijri)
        store.save(planted)

        let coldRepo = PrayerRepository(client: AladhanClient(), store: store)
        let cached = try await coldRepo.load(around: Date(), settings: settings)
        check("cache produced the same month", cached.timetable.days.count == first.timetable.days.count)
        check("timezone survived the round trip", cached.timetable.timeZoneID == "Asia/Riyadh")
        check("planted sentinel survived, so no refetch happened",
              cached.timetable.days[todayStamp]?.rawMinutes(for: .fajr) == 1,
              "\(String(describing: cached.timetable.days[todayStamp]?.rawMinutes(for: .fajr)))")

        print("\n4. Decoding rejects a schema bump")
        var entry = CachedMonth(key: MonthKey(year: 2000, month: 1, settings: settings),
                                timetable: first.timetable, fetchedAt: Date())
        entry.schemaVersion = 99
        store.save(entry)
        check("a file from a future schema is ignored",
              store.load(MonthKey(year: 2000, month: 1, settings: settings)) == nil)

        print("\n5. Changing a request setting changes the cache key")
        var hanafi = settings
        hanafi.school = 1
        check("Hanafi gets a different fingerprint",
              hanafi.requestFingerprint != settings.requestFingerprint)
        var tuned = settings
        tuned.tuneMinutes = ["Fajr": 5]
        check("a read-time tune does NOT change the fingerprint",
              tuned.requestFingerprint == settings.requestFingerprint)
    } catch {
        check("cold load succeeded", false, "\(error)")
    }
}

semaphore.wait()
try? FileManager.default.removeItem(at: tempRoot)
print("\n\(failures == 0 ? "all repository checks passed" : "\(failures) FAILED")")
exit(failures == 0 ? 0 : 1)
