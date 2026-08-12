
import Foundation
import os
import UserNotifications

/// Keeps pending notifications in sync with the schedule.
///
/// Two properties matter and both were missing before:
///
/// 1. **Idempotent.** Identifiers are derived from the prayer, the day and a fingerprint
///    of the settings that shape the notification. Rescheduling with unchanged settings
///    adds and removes nothing; changing a setting rotates every identifier so the old
///    ones fall out of the desired set naturally.
/// 2. **Multi-day.** The app runs unattended for weeks, so it schedules a horizon of
///    days ahead and slides it forward on every prayer boundary.
@MainActor
final class PrayerNotificationScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// `UNUserNotificationCenter` keeps at most this many pending requests per app and
    /// silently discards the furthest-future ones beyond it.
    nonisolated static let pendingLimit = 64
    /// Leave headroom so an unrelated request never pushes a prayer off the end.
    nonisolated static let reserved = 4

    /// How many days ahead can be scheduled without exceeding the cap.
    nonisolated static func horizonDays(enabledPrayers: Int, hasReminders: Bool) -> Int {
        let perDay = max(1, enabledPrayers * (hasReminders ? 2 : 1))
        return min(7, max(2, (pendingLimit - reserved) / perDay))
    }

    nonisolated struct PlannedRequest {
        let identifier: String
        let date: Date
        let title: String
        let body: String
        let sound: UNNotificationSound?
    }

    /// Builds the set of notifications that *should* exist, for the days covered by
    /// `timetable`. Pure enough to reason about; the delivery half is `reconcile`.
    nonisolated static func plan(now: Date,
                     timetable: PrayerTimetable,
                     settings: PrayerSettings,
                     isEnabled: (PrayerKey) -> Bool,
                     sound: (PrayerKey) -> UNNotificationSound?) -> [PlannedRequest] {
        let enabled = PrayerKey.notifiable.filter(isEnabled)
        guard !enabled.isEmpty else { return [] }

        let horizon = horizonDays(enabledPrayers: enabled.count,
                                  hasReminders: settings.reminderMinutes > 0)
        let fingerprint = settings.notificationFingerprint
        let language = settings.language

        let events = PrayerScheduleCalculator.events(dayOffsets: 0...horizon,
                                                     from: now,
                                                     timetable: timetable,
                                                     settings: settings)

        var planned: [PlannedRequest] = []
        for event in events where !event.key.isNightMarker {
            guard event.date > now, enabled.contains(event.key) else { continue }
            let name = event.name(language: language)

            planned.append(PlannedRequest(
                identifier: "prayer_\(event.key.rawValue)_\(event.dateStamp)_\(fingerprint)",
                date: event.date,
                title: Translations.string("prayer_time", language: language),
                body: String(format: Translations.string("prayer_time_body", language: language), name),
                sound: sound(event.key)))

            guard settings.reminderMinutes > 0 else { continue }
            let reminderDate = event.date.addingTimeInterval(TimeInterval(-settings.reminderMinutes * 60))
            guard reminderDate > now else { continue }

            let bodyKey = settings.reminderMinutes == 60 ? "prayer_reminder_body_hour" : "prayer_reminder_body"
            let body = settings.reminderMinutes == 60
                ? String(format: Translations.string(bodyKey, language: language), name)
                : String(format: Translations.string(bodyKey, language: language), name, "\(settings.reminderMinutes)")

            planned.append(PlannedRequest(
                identifier: "reminder_\(event.key.rawValue)_\(event.dateStamp)_\(fingerprint)",
                date: reminderDate,
                title: Translations.string("prayer_reminder_title", language: language),
                body: body,
                sound: .default))
        }

        // Soonest first, so if anything has to be dropped it is the furthest out.
        return planned.sorted { $0.date < $1.date }
            .prefix(pendingLimit - reserved)
            .map { $0 }
    }

    /// Adds what is missing and removes what no longer belongs, rather than clearing
    /// and rebuilding. Also sweeps identifiers from older schemes.
    func reconcile(now: Date = Date(),
                   timetable: PrayerTimetable,
                   settings: PrayerSettings) async {
        let planned = Self.plan(
            now: now,
            timetable: timetable,
            settings: settings,
            isEnabled: { PrayerNotificationSettings.isEnabled(for: $0.rawValue) },
            sound: { PrayerNotificationSettings.sound(for: $0.rawValue).notificationSound })

        let desired = Dictionary(uniqueKeysWithValues: planned.map { ($0.identifier, $0) })
        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter {
            $0.identifier.hasPrefix("prayer_") || $0.identifier.hasPrefix("reminder_")
                || $0.identifier.hasPrefix("test_prayer_")
        }

        let existing = Set(ours.map(\.identifier))
        let obsolete = existing.subtracting(desired.keys)
        if !obsolete.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(obsolete))
            Log.notifications.notice("Removed \(obsolete.count) obsolete: \(obsolete.sorted().prefix(8).joined(separator: ", "), privacy: .public)")
        }
        Log.notifications.notice("Pending before reconcile: \(pending.count) total, \(ours.count) ours")

        let calendar = timetable.calendar
        let timeZone = timetable.timeZone
        for (identifier, request) in desired where !existing.contains(identifier) {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = request.sound
            // No badge: this is a menu bar app, and the count only ever accumulated
            // into a red dot the user had no way to clear.

            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.date)
            // Without an explicit zone the trigger is device-local, which would undo the
            // point of resolving instants in the city's zone.
            components.timeZone = timeZone

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            } catch {
                Log.notifications.error("Could not schedule \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        let added = desired.count - existing.intersection(desired.keys).count
        // `pendingNotificationRequests()` is eventually consistent: shortly after a
        // batch of adds — and early in app startup — it under-reports what the store
        // actually holds. Treat this count as indicative, not authoritative, and don't
        // "fix" a shortfall by shrinking the horizon. Because identifiers are
        // deterministic, a stale read just re-adds an identical request, which replaces
        // rather than duplicates.
        let reported = await center.pendingNotificationRequests().count
        Log.notifications.notice("Reconciled: \(desired.count) desired, +\(added) added, -\(obsolete.count) removed (store reports \(reported) pending; may lag)")
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}
