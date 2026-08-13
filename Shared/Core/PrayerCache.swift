
import Foundation
import os

/// Identifies one cached month. The fingerprint covers exactly the settings that
/// change what the server returns, so read-time adjustments never invalidate a file.
nonisolated struct MonthKey: Hashable, Codable, Sendable {
    let year: Int
    let month: Int
    let fingerprint: String

    init(year: Int, month: Int, settings: PrayerSettings) {
        self.year = year
        self.month = month
        self.fingerprint = settings.requestFingerprint
    }

    var fileName: String {
        String(format: "%04d-%02d_%@.json", year, month, fingerprint)
    }

    /// The month containing `date`, in `calendar`'s zone.
    static func containing(_ date: Date, calendar: Calendar, settings: PrayerSettings) -> MonthKey {
        let c = calendar.dateComponents([.year, .month], from: date)
        return MonthKey(year: c.year ?? 1970, month: c.month ?? 1, settings: settings)
    }
}

nonisolated struct CachedMonth: Codable, Sendable {
    /// Bump when the on-disk shape changes; older files are then ignored rather than
    /// mis-decoded.
    static let currentSchemaVersion = 1
    static let staleAfter: TimeInterval = 30 * 24 * 60 * 60

    var schemaVersion: Int = CachedMonth.currentSchemaVersion
    var key: MonthKey
    var timetable: PrayerTimetable
    var fetchedAt: Date

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > Self.staleAfter
    }
}

/// Plain Codable JSON on disk.
///
/// Deliberately not Core Data or SwiftData: SwiftData needs macOS 14 (the target is 13),
/// and the payload is a few tens of KB per month. JSON is atomically writable, readable
/// synchronously from a widget with no setup, and easy to inspect or delete by hand.
nonisolated struct MonthCacheStore: Sendable {
    let root: URL

    init(root: URL = AppPaths.cacheDirectory) {
        self.root = root
    }

    func load(_ key: MonthKey) -> CachedMonth? {
        let url = root.appendingPathComponent(key.fileName)
        guard let data = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(CachedMonth.self, from: data),
              entry.schemaVersion == CachedMonth.currentSchemaVersion
        else { return nil }
        return entry
    }

    func save(_ entry: CachedMonth) {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entry)
            try data.write(to: root.appendingPathComponent(entry.key.fileName), options: .atomic)
        } catch {
            // A cache write failing is not worth interrupting the user over; the app
            // still has the data in memory for this session.
            Log.data.error("Could not write cache for \(entry.key.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Drops files for months far from `now` and for stale setting fingerprints.
    func prune(around now: Date, keepingMonths: Int = 3) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let keep: Set<String> = Set((-keepingMonths...keepingMonths).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset, to: now) else { return nil }
            let c = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        })

        for file in files where file.pathExtension == "json" {
            let prefix = String(file.lastPathComponent.prefix(7))
            if !keep.contains(prefix) {
                try? fm.removeItem(at: file)
            }
        }
    }
}

nonisolated enum AppPaths {
    /// The App Group container when it exists, the app's own sandbox when it does not.
    ///
    /// The widget is a separate process and cannot read the app's private container, so
    /// the cache has to live somewhere both can reach. The fallback keeps a build without
    /// the entitlement working exactly as it did before.
    static var supportDirectory: URL {
        if let container = SharedStore.containerURL {
            return container
                .appendingPathComponent("Library/Application Support/SalatTimes", isDirectory: true)
        }
        return legacySupportDirectory
    }

    /// Where months were cached before the App Group. Still read once, to move them.
    static var legacySupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("SalatTimes", isDirectory: true)
    }

    /// Moves the old cache into the group container, once.
    ///
    /// Cached months are disposable — a miss just refetches — but only if there is a
    /// network. Carrying them over means an app updated while offline still has times to
    /// show, which is the whole point of the cache.
    static func migrateCacheIfNeeded() {
        guard SharedStore.containerURL != nil else { return }
        let source = legacySupportDirectory
        let destination = supportDirectory
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path), !fm.fileExists(atPath: destination.path) else { return }

        do {
            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try fm.moveItem(at: source, to: destination)
            Log.data.notice("Moved the cache into the App Group container")
        } catch {
            // Not fatal: the repository recreates what it needs and refetches.
            Log.data.error("Could not move the cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    static var cacheDirectory: URL {
        supportDirectory.appendingPathComponent("Cache", isDirectory: true)
    }
}
