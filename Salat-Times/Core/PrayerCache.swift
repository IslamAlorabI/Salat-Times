
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
    /// Inside the sandbox container today. When the widget lands this moves to the
    /// App Group container — hence the single accessor.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("SalatTimes", isDirectory: true)
    }

    static var cacheDirectory: URL {
        supportDirectory.appendingPathComponent("Cache", isDirectory: true)
    }
}
