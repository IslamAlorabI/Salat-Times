
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
    /// The place the times are for: a `City` raw value, or a detected location's name.
    /// It labels the popover, the schedule window and the export file name — it is never
    /// what the request is built from, which is always the coordinates below.
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

    /// True when the coordinates above came from CoreLocation rather than the city list.
    /// Not part of any fingerprint — the coordinates already are — it only tells the UI
    /// which control to show as active.
    var usesDeviceLocation: Bool = false

    // Display
    var language: String
    var numberFormat: String
    var use24Hour: Bool

    // Notifications
    var reminderMinutes: Int
    var warningMinutes: Int
    /// `PrayerKey.rawValue`s the user wants to be notified about.
    var enabledPrayers: Set<String>
    /// `PrayerKey.rawValue` -> `NotificationSound.rawValue`.
    var prayerSounds: [String: String]

    static let defaultMethod = 5   // Egyptian General Authority of Survey

    /// A fixed offset is either off (`0`) or a sane distance from its anchor prayer.
    static let fixedOffsetRange = 15...180

    /// Bumped when the *content* of a notification changes shape.
    ///
    /// A pending request's content is frozen when it is added, so a code change to what a
    /// notification says or how it groups cannot reach the ones already scheduled — they
    /// would keep the old shape for the whole horizon, up to a week. Folding this into
    /// `notificationFingerprint` rotates every identifier exactly once, which makes the
    /// reconciler drop the old requests and add them back in the new shape. It is not a
    /// user setting and never varies at runtime.
    ///
    /// - 1: the original content.
    /// - 2: a prayer and its own reminder share a `threadIdentifier`, so Notification
    ///   Center stacks them into one entry instead of listing two.
    static let notificationContentVersion = 2

    /// Identifies the server response. Two settings with the same fingerprint may share
    /// cached days; anything else must be refetched.
    var requestFingerprint: String {
        String(format: "%.4f_%.4f_%d_%d_%d_%d",
               latitude, longitude, method, school, latitudeAdjustment, midnightMode)
    }

    /// Everything that changes what a scheduled notification would *say*, *when* it
    /// fires, or *how it sounds*. Baked into notification identifiers so that
    /// re-scheduling with unchanged settings is a no-op, while a settings change makes
    /// the old requests fall out of the desired set and get removed.
    ///
    /// `enabledPrayers` is deliberately **not** here: disabling a prayer already drops
    /// it from the desired set, and folding it in would rotate — and so rewrite — every
    /// other prayer's pending requests for nothing. The sounds *are* here, because a
    /// request's sound is fixed at `add` time: without them in the identifier, changing
    /// a sound left the already-pending alerts playing the old one.
    ///
    /// Must be **stable across process launches** — `Swift.Hasher` is randomly seeded
    /// per process, so using it here silently rotated every identifier on every restart
    /// and made the reconciler remove and re-add the whole schedule each time.
    var notificationFingerprint: String {
        var parts: [String] = [
            requestFingerprint,
            language,
            "v\(Self.notificationContentVersion)",
            "\(reminderMinutes)",
            "\(fajrBeforeSunriseMinutes)",
            "\(ishaAfterMaghribMinutes)",
        ]
        for key in PrayerKey.allCases.map(\.rawValue).sorted() {
            parts.append("\(key):\(tuneMinutes[key] ?? 0):\(prayerSounds[key] ?? "default")")
        }
        return StableHash.digest(parts.joined(separator: "|"))
    }

    static func load(from defaults: UserDefaults = SharedStore.defaults) -> PrayerSettings {
        let cityRaw = defaults.string(forKey: "selectedCityRaw") ?? City.cairo.rawValue
        let city = City.allCases.first { $0.rawValue == cityRaw } ?? .cairo

        // Device location wins only when it is switched on *and* there is a fix to use.
        // Turning the mode on before the first fix arrives — or after a stored fix was
        // corrupted — falls back to the picked city rather than to nowhere, which is why
        // the picked city is always read first.
        let deviceFix = LocationMode.from(defaults.string(forKey: DeviceLocation.Keys.mode)) == .device
            ? DeviceLocation.load(from: defaults)
            : nil
        let coords = deviceFix.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            ?? city.coordinates

        let storedMethod = defaults.integer(forKey: "calculationMethod")

        // Clamp on read rather than trusting the store: these keys are also written by
        // the widget and by hand during debugging, and an out-of-range value would go
        // straight into the request URL or into an instant.
        func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
            min(max(value, range.lowerBound), range.upperBound)
        }
        func fixedOffset(_ key: String) -> Int {
            let value = defaults.integer(forKey: key)
            return value <= 0 ? 0 : clamp(value, to: fixedOffsetRange)
        }

        var tune: [String: Int] = [:]
        var enabled: Set<String> = []
        var sounds: [String: String] = [:]
        for key in PrayerKey.notifiable {
            let value = clamp(defaults.integer(forKey: "tune_\(key.rawValue)"),
                              to: PrayerAdjustments.tuneRange)
            if value != 0 { tune[key.rawValue] = value }
            // Absent means on: notifications have always been opt-out, not opt-in.
            if defaults.object(forKey: "notification_\(key.rawValue)_enabled") as? Bool ?? true {
                enabled.insert(key.rawValue)
            }
            sounds[key.rawValue] = defaults.string(forKey: "notification_\(key.rawValue)_sound") ?? "default"
        }

        return PrayerSettings(
            cityRaw: deviceFix?.displayName ?? city.rawValue,
            latitude: coords.latitude,
            longitude: coords.longitude,
            // 0 means "never set"; the app has always fallen back to the Egyptian method.
            method: storedMethod == 0 ? defaultMethod : storedMethod,
            school: clamp(defaults.integer(forKey: "asrSchool"), to: 0...1),
            latitudeAdjustment: clamp(defaults.integer(forKey: "latitudeAdjustment"), to: 0...3),
            midnightMode: clamp(defaults.integer(forKey: "midnightMode"), to: 0...1),
            tuneMinutes: tune,
            fajrBeforeSunriseMinutes: fixedOffset("fajrBeforeSunriseMinutes"),
            ishaAfterMaghribMinutes: fixedOffset("ishaAfterMaghribMinutes"),
            usesDeviceLocation: deviceFix != nil,
            language: defaults.string(forKey: "appLanguage") ?? "ar",
            numberFormat: defaults.string(forKey: "numberFormat") ?? "western",
            use24Hour: defaults.object(forKey: "timeFormat24") as? Bool ?? true,
            reminderMinutes: defaults.integer(forKey: "reminderInterval"),
            warningMinutes: defaults.integer(forKey: "warningInterval"),
            enabledPrayers: enabled,
            prayerSounds: sounds
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
