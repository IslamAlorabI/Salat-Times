
import Foundation
import os
import CoreLocation

/// One-shot access to where the Mac is, as an `async` call.
///
/// CoreLocation is delegate-driven and answers whenever it feels like it; every caller
/// here wants "give me a place or an error, once". The bridging is all in this file so
/// nothing else in the app has to hold a `CLLocationManager` or reason about which
/// delegate callback resumes what.
///
/// Two things this must never do, both of which it got wrong in earlier shapes:
///  - resume a continuation twice (CoreLocation will happily call `didUpdateLocations`
///    more than once, and a second `resume` traps);
///  - hang forever. `requestLocation()` does eventually time out on its own, but not on
///    a Mac with location services switched off at the system level, where no callback
///    ever arrives.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Failure: LocalizedError, Equatable {
        /// The user said no, or a profile forbids it. Recoverable only in System Settings.
        case denied
        /// A fix could not be produced — services off, no hardware, no network.
        case unavailable
        case timedOut

        var errorDescription: String? {
            switch self {
            case .denied: return "Location access was denied"
            case .unavailable: return "No location could be determined"
            case .timedOut: return "Locating timed out"
            }
        }
    }

    /// Long enough for a cold Wi-Fi-based fix, short enough that a stuck request gives
    /// the user their button back.
    private static let fixTimeout: Duration = .seconds(20)

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var fixContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // A kilometre is plenty: the fix is rounded to ~1.1 km before it is stored, and
        // asking for less accuracy gets an answer sooner and reads fewer sensors.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    /// macOS answers `requestWhenInUseAuthorization` with `.authorizedAlways`, but the
    /// other two are accepted rather than assumed away — a status this misreads would
    /// leave the app refusing to locate a Mac that had already said yes.
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .authorizedAlways, .authorizedWhenInUse: return true
        default: return false
        }
    }

    var isDenied: Bool {
        switch authorizationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Asks for permission if it has not been asked yet, takes one fix, and reverse-
    /// geocodes it. Throws `Failure` rather than CoreLocation's errors so callers can
    /// tell "say no" apart from "could not".
    func currentLocation(language: String) async throws -> DeviceLocation {
        var status = authorizationStatus
        if status == .notDetermined {
            status = await requestAuthorization()
        }
        guard !isDenied else { throw Failure.denied }
        guard isAuthorized else { throw Failure.unavailable }

        let location = try await requestFix()
        let place = await reverseGeocode(location, language: language)

        return DeviceLocation(latitude: location.coordinate.latitude,
                              longitude: location.coordinate.longitude,
                              placeName: place.name,
                              countryCode: place.countryCode,
                              updatedAt: Date())
    }

    // MARK: - Authorization

    private func requestAuthorization() async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            // A second caller while a prompt is already up would strand one of them.
            if authorizationContinuation != nil {
                continuation.resume(returning: manager.authorizationStatus)
                return
            }
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            let status = manager.authorizationStatus
            // `.notDetermined` also arrives once when the delegate is first set; that is
            // not an answer to the prompt, so keep waiting.
            guard status != .notDetermined, let continuation = authorizationContinuation else { return }
            authorizationContinuation = nil
            continuation.resume(returning: status)
        }
    }

    // MARK: - The fix

    private func requestFix() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            guard fixContinuation == nil else {
                continuation.resume(throwing: Failure.unavailable)
                return
            }
            fixContinuation = continuation

            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: Self.fixTimeout)
                guard !Task.isCancelled else { return }
                self?.finishFix(with: .failure(Failure.timedOut))
            }

            manager.requestLocation()
        }
    }

    /// The one place a fix continuation is resumed, so it cannot happen twice.
    private func finishFix(with result: Result<CLLocation, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation = fixContinuation else { return }
        fixContinuation = nil
        continuation.resume(with: result)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let location = locations.last else {
                finishFix(with: .failure(Failure.unavailable))
                return
            }
            finishFix(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            Log.data.error("Location failed: \(error.localizedDescription, privacy: .public)")
            let failure: Failure = (error as? CLError)?.code == .denied ? .denied : .unavailable
            finishFix(with: .failure(failure))
        }
    }

    // MARK: - Naming the place

    /// Best-effort: a fix with no name is still a usable fix, so a geocoding failure is
    /// logged and swallowed rather than thrown. `DeviceLocation.displayName` falls back
    /// to the coordinates themselves.
    private func reverseGeocode(_ location: CLLocation,
                                language: String) async -> (name: String, countryCode: String) {
        do {
            let locale = Locale(identifier: Translations.locale(language))
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            guard let placemark = placemarks.first else { return ("", "") }

            // Locality is the city. Falling back through the administrative area and the
            // country keeps somewhere remote from being labelled with nothing at all.
            let name = placemark.locality
                ?? placemark.subAdministrativeArea
                ?? placemark.administrativeArea
                ?? placemark.country
                ?? ""
            return (name, placemark.isoCountryCode ?? "")
        } catch {
            Log.data.error("Reverse geocoding failed: \(error.localizedDescription, privacy: .public)")
            return ("", "")
        }
    }
}
