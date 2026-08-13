
import Foundation

/// The one place that decides *where* the app's state lives.
///
/// A widget is a separate process in its own sandbox: it cannot see the app's
/// `UserDefaults.standard`, and it cannot read the app's Application Support folder. An
/// App Group container is the shared box both can open, and this enum is the only thing
/// that knows its name.
///
/// Two rules hold it together:
///
/// - **The fallback is load-bearing, not decoration.** A build without the entitlement —
///   unsigned, ad-hoc, or a target someone forgot to tick — has no group container. If
///   that case returned an empty suite, every setting would read as its default and the
///   app would behave like a fresh install while quietly discarding the real one. It falls
///   back to exactly what it used before instead.
/// - **Migration copies, never moves.** The old `UserDefaults.standard` values stay where
///   they are, so a build without the group still finds them.
nonisolated enum SharedStore {
    /// App Groups on macOS must be prefixed with the team identifier. The bare
    /// `group.something` form that works on iOS is rejected here, and the container comes
    /// back `nil` — which is exactly the case the fallback below covers.
    static let appGroupIdentifier = "HNTYPSZB5M.group.Islam-AlorabI.Salat-Times"

    /// Non-nil only when the entitlement is actually in place, which makes it the honest
    /// probe for "is the group usable" — `UserDefaults(suiteName:)` hands back a suite
    /// whether or not the container exists.
    static let containerURL: URL? =
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)

    static var isGroupAvailable: Bool { containerURL != nil }

    /// The store every part of the app reads and writes: the group suite when it exists,
    /// `.standard` when it does not.
    static let defaults: UserDefaults = {
        guard containerURL != nil, let suite = UserDefaults(suiteName: appGroupIdentifier) else {
            return .standard
        }
        return suite
    }()

    /// Set once the copy below has run, in the *destination*, so it happens exactly once.
    static let migrationKey = "didMigrateToAppGroup"

    /// Keys this app owns.
    ///
    /// `UserDefaults` is full of things the system and AppKit put there — window frames,
    /// spelling preferences, `NSNavLastRootDirectory`. Copying those into a shared suite
    /// would be both rude and unpredictable, so migration works from a list rather than
    /// sweeping everything.
    static let ownedKeys: Set<String> = [
        "appLanguage", "selectedCityRaw", "calculationMethod", "timeFormat24",
        "numberFormat", "hasShownWelcome", "reminderInterval", "warningInterval",
        "asrSchool", "latitudeAdjustment", "midnightMode",
        "fajrBeforeSunriseMinutes", "ishaAfterMaghribMinutes",
        "listMaterial", "showNightTimes",
        DeviceLocation.Keys.mode, DeviceLocation.Keys.latitude, DeviceLocation.Keys.longitude,
        DeviceLocation.Keys.placeName, DeviceLocation.Keys.countryCode,
        DeviceLocation.Keys.updatedAt, DeviceLocation.Keys.isApproximate,
        DeviceLocation.Keys.followDevice,
    ]

    /// The per-prayer keys are built from `PrayerKey`, so they cannot be listed by hand
    /// without going stale the next time a prayer is added.
    static let ownedPrefixes = ["tune_", "notification_"]

    static func isOwned(_ key: String) -> Bool {
        ownedKeys.contains(key) || ownedPrefixes.contains { key.hasPrefix($0) }
    }

    /// Copies this app's settings into `destination` once.
    ///
    /// Existing values in the destination win: the migration must never undo a change the
    /// user made after it first ran, and it must be safe to call on every launch.
    @discardableResult
    static func migrateIfNeeded(from source: UserDefaults = .standard,
                                to destination: UserDefaults = defaults) -> Int {
        guard source !== destination, !destination.bool(forKey: migrationKey) else { return 0 }

        var copied = 0
        for (key, value) in source.dictionaryRepresentation() where isOwned(key) {
            guard destination.object(forKey: key) == nil else { continue }
            destination.set(value, forKey: key)
            copied += 1
        }
        destination.set(true, forKey: migrationKey)
        return copied
    }
}
