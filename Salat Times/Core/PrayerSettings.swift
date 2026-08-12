
import Foundation
import CoreLocation

/// An immutable snapshot of everything the schedule depends on.
///
/// Taking a snapshot keeps the calculator pure — it never reads `UserDefaults` — and
/// gives one place to ask "did anything that matters actually change?".
///
/// The fields split into two groups, and the split matters:
///  - **Request fields** (`method`, `school`, `latitudeAdjustment`, `midnightMode`,
///    latitude/longitude) change what the server returns, so they belong to the cache key.
///  - **Read-time fields** (`tuneMinutes`, the fixed offsets) are applied locally when a
///    day is read, so changing them must *not* invalidate the cache.
nonisolated struct PrayerSettings: Sendable, Equatable {
    // Request fields
    var cityRaw: String
    var latitude: Double
    var longitude: Double
    var method: Int
    var school: Int              // 0 Shafi'i, 1 Hanafi
    var latitudeAdjustment: Int  // 0 none, 1 middle of night, 2 one seventh, 3 angle based
    var midnightMode: Int        // 0 standard, 1 Jafari

    // Read-time adjustments
    var tuneMinutes: [String: Int]
    var fajrBeforeSunriseMinutes: Int   // 0 = off
    var ishaAfterMaghribMinutes: Int    // 0 = off

    // Display
    var language: String
    var numberFormat: String
    var use24Hour: Bool

    // Notifications
    var reminderMinutes: Int
    var warningMinutes: Int

    static let defaultMethod = 5   // Egyptian General Authority of Survey

    /// Identifies the server response. Two settings with the same fingerprint may share
    /// cached days; anything else must be refetched.
    var requestFingerprint: String {
        String(format: "%.4f_%.4f_%d_%d_%d_%d",
               latitude, longitude, method, school, latitudeAdjustment, midnightMode)
    }

    /// Everything that changes what a scheduled notification would *say* or *when* it
    /// fires. Baked into notification identifiers so that re-scheduling with unchanged
    /// settings is a no-op, while a settings change makes the old requests fall out of
    /// the desired set and get removed.
    /// Must be **stable across process launches** — `Swift.Hasher` is randomly seeded
    /// per process, so using it here silently rotated every identifier on every restart
    /// and made the reconciler remove and re-add the whole schedule each time.
    var notificationFingerprint: String {
        var parts: [String] = [
            requestFingerprint,
            language,
            "\(reminderMinutes)",
            "\(fajrBeforeSunriseMinutes)",
            "\(ishaAfterMaghribMinutes)",
        ]
        for key in PrayerKey.allCases.map(\.rawValue).sorted() {
            parts.append("\(key):\(tuneMinutes[key] ?? 0)")
        }
        return StableHash.digest(parts.joined(separator: "|"))
    }

    static func load(from defaults: UserDefaults = .standard) -> PrayerSettings {
        let cityRaw = defaults.string(forKey: "selectedCityRaw") ?? City.cairo.rawValue
        let city = City.allCases.first { $0.rawValue == cityRaw } ?? .cairo
        let coords = city.coordinates

        let storedMethod = defaults.integer(forKey: "calculationMethod")

        var tune: [String: Int] = [:]
        for key in PrayerKey.notifiable {
            let value = defaults.integer(forKey: "tune_\(key.rawValue)")
            if value != 0 { tune[key.rawValue] = value }
        }

        return PrayerSettings(
            cityRaw: city.rawValue,
            latitude: coords.latitude,
            longitude: coords.longitude,
            // 0 means "never set"; the app has always fallen back to the Egyptian method.
            method: storedMethod == 0 ? defaultMethod : storedMethod,
            school: defaults.integer(forKey: "asrSchool"),
            latitudeAdjustment: defaults.integer(forKey: "latitudeAdjustment"),
            midnightMode: defaults.integer(forKey: "midnightMode"),
            tuneMinutes: tune,
            fajrBeforeSunriseMinutes: defaults.integer(forKey: "fajrBeforeSunriseMinutes"),
            ishaAfterMaghribMinutes: defaults.integer(forKey: "ishaAfterMaghribMinutes"),
            language: defaults.string(forKey: "appLanguage") ?? "ar",
            numberFormat: defaults.string(forKey: "numberFormat") ?? "western",
            use24Hour: defaults.object(forKey: "timeFormat24") as? Bool ?? true,
            reminderMinutes: defaults.integer(forKey: "reminderInterval"),
            warningMinutes: defaults.integer(forKey: "warningInterval")
        )
    }
}

/// Per-prayer corrections, applied every time a day is read and never written back.
nonisolated enum PrayerAdjustments {
    static let tuneRange = -30...30

    /// Returns minutes since local midnight for `key`, with the user's corrections applied.
    /// `all` is the day's raw table, needed because the fixed offsets are defined
    /// relative to another prayer.
    static func adjustedMinutes(for key: PrayerKey,
                                in day: DayTimings,
                                settings: PrayerSettings) -> Int? {
        guard var value = day.rawMinutes(for: key) else { return nil }

        // Fixed offsets replace the calculated time outright.
        switch key {
        case .fajr where settings.fajrBeforeSunriseMinutes > 0:
            if let sunrise = day.rawMinutes(for: .sunrise) {
                value = sunrise - settings.fajrBeforeSunriseMinutes
            }
        case .isha where settings.ishaAfterMaghribMinutes > 0:
            if let maghrib = day.rawMinutes(for: .maghrib) {
                value = maghrib + settings.ishaAfterMaghribMinutes
            }
        default:
            break
        }

        return value + (settings.tuneMinutes[key.rawValue] ?? 0)
    }
}
