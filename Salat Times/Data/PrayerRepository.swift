
import Foundation

/// Cache-first access to prayer times.
///
/// The contract, mirroring the Android sibling: serve from disk when we can, go to the
/// network only when a month is missing or stale, and if the network fails, fall back to
/// whatever is cached — even if it is stale — rather than showing nothing.
actor PrayerRepository {
    struct Snapshot: Sendable {
        var timetable: PrayerTimetable
        /// When the newest month in this result was fetched, or `nil` if everything
        /// came from a cache we never refreshed this session.
        var fetchedAt: Date?
        /// True when the network failed and stale cache was used instead.
        var servedStale: Bool
    }

    enum RepositoryError: LocalizedError {
        case noDataAvailable
        var errorDescription: String? { "No cached prayer times and the network is unavailable" }
    }

    private let client: AladhanClient
    private let store: MonthCacheStore
    private var memory: [MonthKey: CachedMonth] = [:]

    init(client: AladhanClient = AladhanClient(), store: MonthCacheStore = MonthCacheStore()) {
        self.client = client
        self.store = store
    }

    /// Everything needed to schedule around `date`: the months covering the event
    /// window, plus the next month when we are near the end of the current one.
    func load(around date: Date, settings: PrayerSettings, forceRefresh: Bool = false) async throws -> Snapshot {
        // The zone is only known once a month has been fetched. Until then the device's
        // zone is a good enough guess for *which month to ask for*; it never leaks into
        // the times themselves.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = knownTimeZone(for: settings) ?? .current

        var timetable: PrayerTimetable?
        var newestFetch: Date?
        var servedStale = false
        var loadedAnything = false
        var lastError: Error?

        for key in monthKeys(around: date, calendar: calendar, settings: settings) {
            do {
                let entry = try await month(key, settings: settings, forceRefresh: forceRefresh)
                if timetable == nil {
                    timetable = entry.timetable
                } else {
                    timetable?.merge(entry.timetable)
                }
                loadedAnything = true
                if entry.isStale() {
                    servedStale = true
                } else if newestFetch == nil || entry.fetchedAt > newestFetch! {
                    newestFetch = entry.fetchedAt
                }
            } catch {
                // A missing *future* month is survivable — the current month is what
                // matters. Only give up if nothing at all could be loaded.
                lastError = error
            }
        }

        guard loadedAnything, let timetable else {
            throw lastError ?? RepositoryError.noDataAvailable
        }

        store.prune(around: date)
        return Snapshot(timetable: timetable, fetchedAt: newestFetch, servedStale: servedStale)
    }

    /// One specific month, whichever month `date` falls in.
    ///
    /// `load(around:)` deliberately only reaches for the months the *scheduler* needs.
    /// The schedule window's stepper can walk to any month, so it asks for one directly —
    /// same cache-first contract, same stale-beats-nothing fallback, and a month the user
    /// browses to is cached like any other.
    func month(containing date: Date, settings: PrayerSettings) async throws -> Snapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = knownTimeZone(for: settings) ?? .current

        let key = MonthKey.containing(date, calendar: calendar, settings: settings)
        let entry = try await month(key, settings: settings, forceRefresh: false)
        return Snapshot(timetable: entry.timetable,
                        fetchedAt: entry.isStale() ? nil : entry.fetchedAt,
                        servedStale: entry.isStale())
    }

    // MARK: - Internals

    private func month(_ key: MonthKey, settings: PrayerSettings, forceRefresh: Bool) async throws -> CachedMonth {
        let cached = memory[key] ?? store.load(key)
        if let cached, !forceRefresh, !cached.isStale() {
            memory[key] = cached
            return cached
        }

        do {
            let timetable = try await client.month(year: key.year, month: key.month, settings: settings)
            let entry = CachedMonth(key: key, timetable: timetable, fetchedAt: Date())
            memory[key] = entry
            store.save(entry)
            return entry
        } catch {
            // Stale data beats no data: a month-old table is off by a couple of minutes,
            // an empty screen is off by everything.
            if let cached {
                memory[key] = cached
                return cached
            }
            throw error
        }
    }

    /// Months spanning the event window, plus a prefetch of next month when the end of
    /// this one is close. Usually one request a month in total.
    private func monthKeys(around date: Date, calendar: Calendar, settings: PrayerSettings) -> [MonthKey] {
        var keys: [MonthKey] = []
        func append(_ key: MonthKey) {
            if !keys.contains(key) { keys.append(key) }
        }

        // The calculator looks from yesterday to two days ahead.
        for dayOffset in [-1, 0, 2] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            append(MonthKey.containing(day, calendar: calendar, settings: settings))
        }

        if let daysLeft = daysRemainingInMonth(from: date, calendar: calendar), daysLeft <= 3,
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) {
            append(MonthKey.containing(nextMonth, calendar: calendar, settings: settings))
        }

        return keys
    }

    private func daysRemainingInMonth(from date: Date, calendar: Calendar) -> Int? {
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return nil }
        let day = calendar.component(.day, from: date)
        return range.upperBound - 1 - day
    }

    /// Reuses the zone from anything already loaded for these settings, so repeated
    /// loads pick the right month near a month boundary in a distant time zone.
    private func knownTimeZone(for settings: PrayerSettings) -> TimeZone? {
        let fingerprint = settings.requestFingerprint
        guard let entry = memory.first(where: { $0.key.fingerprint == fingerprint })?.value else { return nil }
        return TimeZone(identifier: entry.timetable.timeZoneID)
    }
}
