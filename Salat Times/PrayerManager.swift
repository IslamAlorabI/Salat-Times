
import Foundation
import os
import CoreLocation
import SwiftUI
import Combine
import UserNotifications
import AppKit

// MARK: - Manager

class PrayerManager: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    @Published var timetable: PrayerTimetable = .empty
    /// Sorted instants spanning yesterday through two days ahead. The single source
    /// of truth for the menu bar, the popover and the notification scheduler.
    @Published var events: [PrayerEvent] = []
    @Published private(set) var settings: PrayerSettings = .load()

    @Published var isLoading = true
    @Published var city: String = "Loading..."
    @Published var errorMessage: String? = nil
    @Published var countdownText: String = ""
    @Published var hijriDate: HijriDate? = nil
    @Published var lastUpdatedFromServer: Date? = nil
    @Published var upcomingPrayerName: String = ""
    @Published var menuBarTitle: String = "Salat Times"
    @Published var isWarningActive: Bool = false
    /// True when the network failed and cached-but-stale times are being shown.
    @Published var isServingStaleData: Bool = false

    /// `.notDetermined` until asked. Surfaced in Settings, because a denial silently
    /// voids every scheduled notification.
    @Published var notificationAuthorization: UNAuthorizationStatus = .notDetermined

    private let repository = PrayerRepository()
    private let scheduler = PrayerNotificationScheduler()
    private let lifecycle = PrayerLifecycle()
    private var refreshTask: Task<Void, Never>?
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var countdownTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var settingsDebounce: Task<Void, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        notificationCenter.delegate = self

        startLifecycle()

        if UserDefaults.standard.bool(forKey: "hasShownWelcome") {
            loadSavedCity()
            startCountdownTimer()
        }

        requestNotificationPermission()
        clearBadgeAndDeliveredNotifications()
        observeSettingsChanges()
    }

    /// Hooks up every reason the schedule can go stale. Without this the app fetched
    /// once at launch and then quietly served yesterday's times forever.
    private func startLifecycle() {
        lifecycle.onBoundary = { [weak self] in
            // A prayer or the city's midnight just passed: slide the notification
            // horizon forward and re-arm. This is what makes the app self-heal after
            // days unattended.
            guard let self else { return }
            self.rebuildEvents()
            self.schedulePrayerNotifications()
            self.refresh()
        }
        lifecycle.onNeedsReschedule = { [weak self] in
            // Woke from sleep, or the clock/zone moved: every computed instant is suspect.
            guard let self else { return }
            self.reloadSettings()
            self.schedulePrayerNotifications()
            self.refresh()
        }
        lifecycle.onShouldRefresh = { [weak self] in
            self?.refresh()
        }
        lifecycle.start()
    }

    /// The next moment the schedule changes meaning: the next prayer, or the city's
    /// midnight if that comes first.
    private func nextBoundary(after now: Date) -> Date {
        var candidates: [Date] = []
        if let next = PrayerScheduleCalculator.next(after: now, in: events) {
            candidates.append(next.date)
        }
        if let midnight = timetable.calendar.nextDate(after: now,
                                                      matching: DateComponents(hour: 0, minute: 0, second: 5),
                                                      matchingPolicy: .nextTime) {
            candidates.append(midnight)
        }
        // A far-future fallback still beats never waking up again.
        return candidates.min() ?? now.addingTimeInterval(3600)
    }

    deinit {
        refreshTask?.cancel()
        countdownTimer?.invalidate()
        settingsDebounce?.cancel()
        MainActor.assumeIsolated { lifecycle.stop() }
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Watches `UserDefaults` for *any* change and reacts to whatever actually moved.
    ///
    /// This replaces a hand-written `.onChange` per control in `SettingsView`, where
    /// every new setting silently did nothing until someone remembered to add its hook.
    /// One observer plus an `Equatable` snapshot means a setting takes effect because it
    /// is *in* `PrayerSettings`, not because a view remembered to say so.
    func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleSettingsDiff()
        }
    }

    /// `didChangeNotification` fires per key written, so dragging a stepper emits a
    /// burst. Coalesce them, then let the equality check discard the ones that changed
    /// nothing we care about.
    private func scheduleSettingsDiff() {
        settingsDebounce?.cancel()
        settingsDebounce = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.applySettingsChange()
        }
    }

    private func applySettingsChange() {
        let updated = PrayerSettings.load()
        let previous = settings
        guard updated != previous else { return }
        settings = updated

        if updated.requestFingerprint != previous.requestFingerprint {
            // City, method, madhab, high-latitude rule or midnight mode: the server
            // returns different numbers, so the cache for these months no longer applies.
            Log.data.notice("Request settings changed; refetching")
            city = City.allCases.first { $0.rawValue == updated.cityRaw }?.rawValue ?? updated.cityRaw
            refresh(force: true)
        } else {
            // Tuning, offsets, language, sounds, reminders: all applied on read, so the
            // cached timetable is still good and this costs no network.
            rebuildEvents()
            schedulePrayerNotifications()
        }
    }

    /// Re-reads the settings snapshot and rebuilds the schedule from the cached
    /// timetable, without hitting the network.
    func reloadSettings() {
        settings = .load()
        rebuildEvents()
    }

    // MARK: - Notifications

    /// Clears the red badge and any notifications sitting in Notification Center.
    ///
    /// Earlier builds set `content.badge = 1` on every prayer alert. In a menu bar app
    /// that only ever accumulated: there is no Dock icon to click, so the count had no
    /// way to be dismissed and just sat there. Called at launch so existing users get
    /// rid of the one they already have.
    func clearBadgeAndDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        if #available(macOS 14.0, *) {
            Task { try? await notificationCenter.setBadgeCount(0) }
        } else {
            NSApplication.shared.dockTile.badgeLabel = nil
        }
    }

    func requestNotificationPermission() {
        Task { [scheduler] in
            let granted = (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
            let status = await scheduler.authorizationStatus()
            self.notificationAuthorization = status
            Log.notifications.notice("Authorization: \(granted ? "granted" : "denied", privacy: .public) (status \(status.rawValue))")
        }
    }

    /// Brings pending notifications in line with the current schedule. Safe to call
    /// as often as you like — unchanged settings produce no churn.
    func schedulePrayerNotifications() {
        guard !timetable.days.isEmpty else { return }
        let timetable = self.timetable
        let settings = self.settings
        Task { [scheduler] in
            await scheduler.reconcile(timetable: timetable, settings: settings)
        }
    }

    func refreshAuthorizationStatus() {
        Task { [scheduler] in
            let status = await scheduler.authorizationStatus()
            self.notificationAuthorization = status
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Loading

    func loadSavedCity() {
        settings = .load()
        let city = City.allCases.first { $0.rawValue == settings.cityRaw } ?? .cairo
        self.city = city.rawValue
        refresh(force: true)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.first != nil else { return }
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.data.error("GPS error: \(error.localizedDescription, privacy: .public)")
        loadSavedCity()
    }

    /// Loads the months around today, cache-first. Only reaches the network when a
    /// month is missing or stale — typically once a month.
    ///
    /// `force` bypasses the staleness check; use it when the settings that shape the
    /// server response have changed.
    func refresh(force: Bool = false) {
        // Only show the spinner on a cold start; a background refresh should not blank
        // out times the user is already looking at.
        if timetable.days.isEmpty { isLoading = true }

        refreshTask?.cancel()
        let snapshotSettings = settings
        refreshTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.repository.load(around: Date(),
                                                              settings: snapshotSettings,
                                                              forceRefresh: force)
                guard !Task.isCancelled else { return }
                self.apply(snapshot)
            } catch {
                guard !Task.isCancelled else { return }
                Log.data.error("Could not load prayer times: \(error.localizedDescription, privacy: .public)")
                self.isLoading = false
                // Anything already loaded stays on screen; the sync dot going orange is
                // the signal that it is not fresh.
                if self.timetable.days.isEmpty {
                    self.errorMessage = Translations.string("check_internet", language: snapshotSettings.language)
                }
            }
        }
    }

    private func apply(_ snapshot: PrayerRepository.Snapshot) {
        timetable = snapshot.timetable
        lastUpdatedFromServer = snapshot.fetchedAt
        isServingStaleData = snapshot.servedStale
        errorMessage = nil
        isLoading = false
        hijriDate = PrayerScheduleCalculator.day(containing: Date(), timetable: timetable)?.hijri ?? hijriDate
        rebuildEvents()
        schedulePrayerNotifications()
    }

    // MARK: - Countdown

    func startCountdownTimer() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateCountdown() }
        }
        timer.tolerance = 0.1
        // .common so the countdown keeps ticking while a menu is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer

        DispatchQueue.main.async { self.updateCountdown() }
    }

    /// Recomputes the event window. Cheap enough to call on any change, and the
    /// per-second tick then only has to search the result.
    func rebuildEvents() {
        let now = Date()
        events = PrayerScheduleCalculator.events(around: now, timetable: timetable, settings: settings)
        updateCountdown()
        lifecycle.arm(nextBoundary: nextBoundary(after: now))
    }

    func updateCountdown() {
        let now = Date()

        guard let upcoming = PrayerScheduleCalculator.next(after: now, in: events) else {
            countdownText = ""
            upcomingPrayerName = ""
            isWarningActive = false
            setMenuBarTitle("Salat Times")
            return
        }

        let countdown = Countdown.from(now, to: upcoming)
        countdownText = countdown.compactString(language: settings.language,
                                                numberFormat: settings.numberFormat)
        upcomingPrayerName = upcoming.name(language: settings.language)

        isWarningActive = settings.warningMinutes > 0
            && countdown.totalSeconds > 0
            && countdown.totalSeconds <= settings.warningMinutes * 60

        setMenuBarTitle("\(upcomingPrayerName) -\(countdownText)")
    }

    /// Assigning unconditionally every second invalidated the menu bar ~86,400 times a
    /// day; the title only actually changes once a minute.
    private func setMenuBarTitle(_ title: String) {
        if menuBarTitle != title { menuBarTitle = title }
    }

    // MARK: - Formatting helpers shared by the views

    /// Formats an instant in the city's zone, honouring the 12/24-hour and numeral settings.
    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timetable.timeZone
        formatter.locale = Locale(identifier: Translations.locale(settings.language))
        formatter.dateFormat = settings.use24Hour ? "HH:mm" : "h:mm a"
        return Translations.localizedNumber(formatter.string(from: date), numberFormat: settings.numberFormat)
    }

    /// The timetable for whichever month `date` falls in, for the schedule window's
    /// stepper. Cache-first like everything else, so walking back through months the user
    /// has already viewed costs nothing.
    func monthTimetable(containing date: Date) async throws -> PrayerTimetable {
        try await repository.month(containing: date, settings: settings).timetable
    }

    /// Today's events in the city's zone, for the popover list.
    var todayEvents: [PrayerEvent] {
        let stamp = DateStamp.format(Date(), in: timetable.calendar)
        return events.filter { $0.dateStamp == stamp }
    }
}
