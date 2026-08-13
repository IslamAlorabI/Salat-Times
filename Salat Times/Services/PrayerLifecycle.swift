
import Foundation
import AppKit
import Network

/// Watches for every reason the schedule might need recomputing.
///
/// The app is expected to sit in the menu bar for weeks. Before this existed it fetched
/// once at launch and never again, so after midnight it showed the previous day's times
/// and — because notifications were only scheduled inside the fetch completion — stopped
/// notifying entirely.
@MainActor
final class PrayerLifecycle {
    /// A prayer time or the city's midnight has just passed: recompute and re-arm.
    var onBoundary: (() -> Void)?
    /// Something happened that invalidates previously computed instants.
    var onNeedsReschedule: (() -> Void)?
    /// A good moment to check whether cached data is still current.
    var onShouldRefresh: (() -> Void)?
    /// The *device's* day rolled over. Separate from `onBoundary`, which also fires at
    /// every prayer — anything that should happen once a day and not six times hangs here.
    var onDayChanged: (() -> Void)?

    private var boundaryTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var monitor: NWPathMonitor?
    private var wasOffline = false
    private var networkDebounce: Task<Void, Never>?

    func start() {
        let center = NotificationCenter.default

        // The device's day rolling over is not the same as the *city's*, so this is a
        // safety net rather than the primary trigger. It arrives on a background thread.
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onBoundary?()
                self?.onDayChanged?()
            }
        })

        // The clock or the zone moving invalidates every instant already computed.
        for name in [NSNotification.Name.NSSystemClockDidChange, NSNotification.Name.NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onNeedsReschedule?() }
            })
        }

        observers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onShouldRefresh?() }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification,
                                                        object: nil, queue: .main) { [weak self] _ in
            // The boundary timer may have fired late or not at all while asleep, so
            // rebuild everything rather than trusting what is on screen.
            MainActor.assumeIsolated { self?.onNeedsReschedule?() }
        })

        startNetworkMonitor()
    }

    func stop() {
        boundaryTimer?.invalidate()
        boundaryTimer = nil
        networkDebounce?.cancel()
        monitor?.cancel()
        monitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
    }

    /// Schedules a single shot at the next moment the schedule changes meaning.
    /// Re-arm after every fire; never leave this unset or the app goes quiet again.
    func arm(nextBoundary: Date) {
        boundaryTimer?.invalidate()

        // A timer scheduled in the past fires immediately and would spin; nudge it.
        let fireDate = max(nextBoundary, Date().addingTimeInterval(1))
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.onBoundary?() }
        }
        timer.tolerance = 1
        // .common, or the timer stalls while a menu is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        boundaryTimer = timer
    }

    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let offline = path.status != .satisfied
                defer { self.wasOffline = offline }
                // Only react to coming back, and debounce — Wi-Fi flaps.
                guard self.wasOffline, !offline else { return }
                self.networkDebounce?.cancel()
                self.networkDebounce = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    self.onShouldRefresh?()
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "salat.network.monitor"))
        self.monitor = monitor
    }
}
