
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
        /// A prayer and its own reminder share one thread, so Notification Center stacks
        /// them as a single entry instead of listing them as two unrelated alerts.
        let threadIdentifier: String
    }

    /// How long a delivered notification survives when there is no schedule to measure it
    /// against — an empty timetable, or a cold start before the first fetch.
    nonisolated static let deliveredFallbackLifetime: TimeInterval = 60 * 60

    /// Tolerance for "delivered in the future". A notification is stamped a moment after
    /// the instant it was triggered for, and clocks are not exact.
    nonisolated static let futureTolerance: TimeInterval = 60

    /// Which already-delivered notifications Notification Center should stop showing.
    ///
    /// Nothing expires on its own: macOS keeps every alert it has ever shown until the
    /// user clears it by hand, so an app that fires six or twelve times a day quietly
    /// builds a wall of them. Two kinds are stale:
    ///
    /// - **Anything delivered before the current prayer.** This is what makes a reminder
    ///   vanish at the moment its prayer arrives — the alert for the prayer replaces it —
    ///   and the previous prayer's alert vanish when the next prayer arrives. What is left
    ///   on screen is at most two things: the current prayer's alert, and the next
    ///   prayer's reminder once it is due.
    /// - **Anything delivered in the future.** Not a paradox but a symptom: if the clock
    ///   jumps forward and then back — a flat RTC battery, a VM resuming, a Hackintosh
    ///   picking the wrong time at boot — every pending request fires at once and is
    ///   stamped with the bogus date. Those would otherwise never expire, because their
    ///   date never becomes old.
    nonisolated static func staleDelivered(_ delivered: [(identifier: String, date: Date)],
                                           now: Date,
                                           currentPrayer: Date?) -> [String] {
        let cutoff = currentPrayer ?? now.addingTimeInterval(-deliveredFallbackLifetime)
        let future = now.addingTimeInterval(futureTolerance)
        return delivered
            .filter { $0.date < cutoff || $0.date > future }
            .map(\.identifier)
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

            let thread = "salat_\(event.key.rawValue)_\(event.dateStamp)"

            planned.append(PlannedRequest(
                identifier: "prayer_\(event.key.rawValue)_\(event.dateStamp)_\(fingerprint)",
                date: event.date,
                title: Translations.string("prayer_time", language: language),
                body: String(format: Translations.string("prayer_time_body", language: language), name),
                sound: sound(event.key),
                threadIdentifier: thread))

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
                sound: .default,
                threadIdentifier: thread))
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
        // Read the per-prayer preferences off the snapshot rather than `UserDefaults`,
        // so what gets scheduled is exactly what the manager diffed and decided to act
        // on — and so the sounds folded into `notificationFingerprint` are the same
        // ones actually attached to the content.
        let planned = Self.plan(
            now: now,
            timetable: timetable,
            settings: settings,
            isEnabled: { settings.enabledPrayers.contains($0.rawValue) },
            sound: { (NotificationSound(rawValue: settings.prayerSounds[$0.rawValue] ?? "default") ?? .defaultSound).notificationSound })

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
            // Groups a prayer with its own reminder, so Notification Center shows one
            // stacked entry per prayer rather than two separate rows.
            content.threadIdentifier = request.threadIdentifier
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

    /// Clears delivered notifications the schedule has moved past.
    ///
    /// Safe to call as often as a boundary fires: it only ever removes what
    /// `staleDelivered` names, and touches nothing this app did not send.
    func pruneDelivered(now: Date = Date(), events: [PrayerEvent]) async {
        let delivered = await center.deliveredNotifications()
        let ours = delivered.filter {
            $0.request.identifier.hasPrefix("prayer_") || $0.request.identifier.hasPrefix("reminder_")
        }
        guard !ours.isEmpty else { return }

        let stale = Self.staleDelivered(ours.map { ($0.request.identifier, $0.date) },
                                        now: now,
                                        currentPrayer: PrayerScheduleCalculator.current(at: now, in: events)?.date)
        guard !stale.isEmpty else { return }

        center.removeDeliveredNotifications(withIdentifiers: stale)
        Log.notifications.notice("Cleared \(stale.count) delivered notification(s) the schedule has passed (\(ours.count - stale.count) kept)")
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }
}
