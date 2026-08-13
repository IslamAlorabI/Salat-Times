
import Foundation
import os
import CoreLocation
import SwiftUI
import Combine
import UserNotifications
import WidgetKit
import AppKit

// MARK: - Manager

/// What the location controls in Settings are showing right now. The manager owns it
/// because detection can also start without the window being open — at launch, or on
/// wake when "follow the device" is on.
enum LocationDetectionState: Equatable {
    case idle
    case detecting
    /// Refused in System Settings; nothing the app can retry its way out of.
    case denied
    /// Services off, no fix, or the request timed out. Retrying is worth offering.
    case failed
}

class PrayerManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
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

    /// Drives the location row in Settings: spinner, denial banner, retry.
    @Published private(set) var locationState: LocationDetectionState = .idle

    private let repository = PrayerRepository()
    private let scheduler = PrayerNotificationScheduler()
    private let lifecycle = PrayerLifecycle()
    private var refreshTask: Task<Void, Never>?
    private let locationService = LocationService()
    /// When the last automatic detection was attempted, successful or not. Manual
    /// "detect now" ignores it; the automatic triggers do not, or waking a laptop six
    /// times in an afternoon would read location six times.
    private var lastAutomaticDetection: Date?
    private let notificationCenter = UNUserNotificationCenter.current()
    private var countdownTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    private var settingsDebounce: Task<Void, Never>?

    override init() {
        super.init()
        notificationCenter.delegate = self

        startLifecycle()

        if SharedStore.defaults.bool(forKey: "hasShownWelcome") {
            loadSavedCity()
            startCountdownTimer()
            detectLocationIfFollowing()
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
            // A prayer just arrived, so its own reminder — and the previous prayer's
            // alert — are no longer what the user needs to see.
            self.pruneDeliveredNotifications()
        }
        lifecycle.onNeedsReschedule = { [weak self] in
            // Woke from sleep, or the clock/zone moved: every computed instant is suspect.
            guard let self else { return }
            self.reloadSettings()
            self.schedulePrayerNotifications()
            self.refresh()
            // A zone change on wake is exactly what travelling looks like.
            self.detectLocationIfFollowing()
            // Whatever fired while the Mac was asleep has almost certainly been
            // overtaken — and a clock that moved is exactly how future-dated
            // notifications appear.
            self.pruneDeliveredNotifications()
        }
        lifecycle.onShouldRefresh = { [weak self] in
            self?.refresh()
            self?.pruneDeliveredNotifications()
        }
        lifecycle.onDayChanged = { [weak self] in
            self?.detectLocationIfFollowing()
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
        // Unconditional: a detected place can be renamed by a later geocode without its
        // coordinates moving, and the label should follow that too.
        city = updated.cityRaw

        if updated.requestFingerprint != previous.requestFingerprint {
            // City, method, madhab, high-latitude rule or midnight mode: the server
            // returns different numbers, so the cache for these months no longer applies.
            Log.data.notice("Request settings changed; refetching")
            refresh(force: true)
        } else {
            // Tuning, offsets, language, sounds, reminders: all applied on read, so the
            // cached timetable is still good and this costs no network.
            rebuildEvents()
            schedulePrayerNotifications()
        }

        // The widget reads the same App Group container, but nothing tells it the
        // contents moved — it would otherwise show the old city until its own timeline
        // happened to expire.
        WidgetCenter.shared.reloadAllTimelines()
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

    /// Sweeps Notification Center of alerts the schedule has moved past. Driven from the
    /// lifecycle hooks — a prayer boundary, waking, becoming active — because those are
    /// exactly the moments an alert stops being current.
    func pruneDeliveredNotifications() {
        let events = self.events
        guard !events.isEmpty else { return }
        Task { [scheduler] in
            await scheduler.pruneDelivered(events: events)
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
        // `cityRaw` is already resolved by `PrayerSettings.load` — a listed city's raw
        // value, or a detected place's name — so it does not need looking up again.
        self.city = settings.cityRaw
        refresh(force: true)
    }

    // MARK: - Device location

    /// How long an automatic detection stays good enough. Applies only to the automatic
    /// triggers; pressing the button in Settings always takes a fresh fix.
    private static let automaticDetectionInterval: TimeInterval = 30 * 60

    var isFollowingDeviceLocation: Bool {
        let defaults = SharedStore.defaults
        return LocationMode.from(defaults.string(forKey: DeviceLocation.Keys.mode)) == .device
            && defaults.bool(forKey: DeviceLocation.Keys.followDevice)
    }

    /// Takes a fix and stores it. Everything downstream — the refetch, the notification
    /// rotation, the menu bar — happens because the new coordinates land in
    /// `UserDefaults` and the debounced settings diff notices, not because this method
    /// tells anyone. That is the same contract every other setting follows.
    func detectLocation() {
        guard locationState != .detecting else { return }
        locationState = .detecting

        Task { @MainActor in
            defer { lastAutomaticDetection = Date() }
            do {
                let fix = try await locationService.currentLocation(language: settings.language)
                store(fix)
                locationState = .idle
            } catch LocationService.Failure.denied {
                Log.data.error("Location denied")
                locationState = .denied
            } catch {
                Log.data.error("Could not detect location: \(error.localizedDescription, privacy: .public)")
                locationState = .failed
            }
        }
    }

    private func detectLocationIfFollowing() {
        guard isFollowingDeviceLocation else { return }
        if let last = lastAutomaticDetection,
           Date().timeIntervalSince(last) < Self.automaticDetectionInterval {
            return
        }
        detectLocation()
    }

    private func store(_ fix: DeviceLocation) {
        let defaults = SharedStore.defaults
        let previous = DeviceLocation.load(from: defaults, keys: .device)
        fix.save(to: defaults, keys: .device)

        // Where the user is stays out of the system log — `log show` is readable by anyone
        // on the machine. Enough is logged to debug the flow, and the place itself is
        // redacted unless someone deliberately enables private data.
        Log.data.notice("""
            Location updated (approximate: \(fix.isApproximate, privacy: .public)): \
            \(fix.displayName, privacy: .private)
            """)

        followMethod(of: fix, previousCountryCode: previous?.countryCode, in: defaults)
    }

    /// Crossing a border moves the calculation method to the local authority's — the same
    /// thing that already happens when a city is picked by hand. Deliberately *only* on a
    /// country change, so it never overwrites a deliberate choice made while staying put.
    private func followMethod(of fix: DeviceLocation,
                              previousCountryCode: String?,
                              in defaults: UserDefaults) {
        guard !fix.countryCode.isEmpty, previousCountryCode != fix.countryCode else { return }
        let method = City.recommendedMethod(forLatitude: fix.latitude, longitude: fix.longitude)
        if defaults.integer(forKey: "calculationMethod") != method {
            Log.data.notice("Country changed; calculation method now \(method)")
            defaults.set(method, forKey: "calculationMethod")
        }
    }

    /// Puts the app back on a picked city. Clearing the mode is enough — the diff sees
    /// different coordinates and refetches.
    func useCityLocation() {
        SharedStore.defaults.set(LocationMode.city.rawValue, forKey: DeviceLocation.Keys.mode)
        locationState = .idle
    }

    /// Switches to device coordinates, detecting immediately if there is no fix yet.
    func useDeviceLocation() {
        SharedStore.defaults.set(LocationMode.device.rawValue, forKey: DeviceLocation.Keys.mode)
        if DeviceLocation.load(keys: .device) == nil {
            detectLocation()
        }
    }

    /// Switches to the hand-picked point. Unlike `useDeviceLocation` there is nothing to
    /// go and fetch: if no point has been chosen yet, `PrayerSettings.load` falls back to
    /// the picked city until the map picker stores one.
    func useManualLocation() {
        SharedStore.defaults.set(LocationMode.manual.rawValue, forKey: DeviceLocation.Keys.mode)
        locationState = .idle
    }

    /// Names a coordinate the user chose and stores it as the manual point. The name is
    /// only ever displayed, so the geocode is allowed to fail — but it is what labels the
    /// popover, the schedule window and the CSV file name, so it is worth asking for.
    func setManualLocation(latitude: Double, longitude: Double, preferredName: String = "") {
        Task { @MainActor in
            let point = await locationService.describe(latitude: latitude,
                                                       longitude: longitude,
                                                       preferredName: preferredName,
                                                       language: settings.language)
            storeManualLocation(point)
        }
    }

    /// Stores a point chosen on the map or typed in. Same contract as a detected fix:
    /// writing it to `UserDefaults` is the whole mechanism, and the debounced diff is what
    /// refetches the month and rotates the notifications.
    func storeManualLocation(_ point: DeviceLocation) {
        let defaults = SharedStore.defaults
        let previous = DeviceLocation.load(from: defaults, keys: .manual)
        point.save(to: defaults, keys: .manual)
        defaults.set(LocationMode.manual.rawValue, forKey: DeviceLocation.Keys.mode)
        locationState = .idle

        Log.data.notice("Manual location set: \(point.displayName, privacy: .private)")
        followMethod(of: point, previousCountryCode: previous?.countryCode, in: defaults)
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
        // A freshly fetched month is exactly what the widget is rendering from.
        WidgetCenter.shared.reloadAllTimelines()
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

        // A middle dot, not a hyphen: "Isha -26m" read as a minus sign.
        setMenuBarTitle("\(upcomingPrayerName) · \(countdownText)")
    }

    /// Assigning unconditionally every second invalidated the menu bar ~86,400 times a
    /// day; the title only actually changes once a minute.
    private func setMenuBarTitle(_ title: String) {
        if menuBarTitle != title { menuBarTitle = title }
    }

    // MARK: - Formatting helpers shared by the views

    /// Formats an instant in the city's zone, honouring the 12/24-hour and numeral settings.
    ///
    /// The formatter is kept rather than rebuilt per call. This is invoked once per prayer
    /// per day, so the monthly schedule asks for 186 of them to draw one month — and
    /// constructing a `DateFormatter` measured five times more expensive than everything
    /// else that pass did put together. Rebuilt only when something it depends on moves,
    /// so the output is identical to constructing one every time.
    private var timeFormatter: (key: String, formatter: DateFormatter)?

    func formattedTime(_ date: Date) -> String {
        let zone = timetable.timeZone
        let key = "\(zone.identifier)|\(settings.language)|\(settings.use24Hour)"

        let formatter: DateFormatter
        if let cached = timeFormatter, cached.key == key {
            formatter = cached.formatter
        } else {
            formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.locale = Locale(identifier: Translations.locale(settings.language))
            formatter.dateFormat = settings.use24Hour ? "HH:mm" : "h:mm a"
            timeFormatter = (key, formatter)
        }
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
