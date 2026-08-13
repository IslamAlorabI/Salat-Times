
import SwiftUI
import AppKit

// The location controls, shared by the settings window and the first-launch sheet so the
// two cannot drift into offering different things.
//
// The mode is an ordinary preference: writing it is the whole mechanism, because
// `PrayerSettings.load` reads it and the debounced diff in `PrayerManager` refetches. The
// `manager` calls below are real actions rather than settings echoes — asking CoreLocation
// for a fix is what puts the system permission prompt on screen, so it has to be started
// by a person, and there is nothing to detect until someone asks.

/// City ↔ device, as a segmented control.
struct LocationModePicker: View {
    let appLanguage: String
    @EnvironmentObject var manager: PrayerManager
    @AppStorage(DeviceLocation.Keys.mode) private var storedMode = LocationMode.city.rawValue

    var body: some View {
        Picker("", selection: Binding(
            get: { LocationMode.from(storedMode) },
            set: { $0 == .device ? manager.useDeviceLocation() : manager.useCityLocation() }
        )) {
            Text(Translations.string("location_choose_city", language: appLanguage)).tag(LocationMode.city)
            Text(Translations.string("location_use_device", language: appLanguage)).tag(LocationMode.device)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// What was detected, when, and the button to do it again.
struct DeviceLocationStatus: View {
    let appLanguage: String
    /// The sheet has no room for a timestamp under the name; the settings pane does.
    var showsTimestamp = true

    @EnvironmentObject var manager: PrayerManager
    @AppStorage(DeviceLocation.Keys.placeName) private var detectedPlace = ""
    @AppStorage(DeviceLocation.Keys.updatedAt) private var detectedAt = 0.0
    @AppStorage("numberFormat") private var numberFormat = "western"

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if showsTimestamp, let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if manager.locationState == .detecting {
                ProgressView().controlSize(.small)
            } else {
                Button(Translations.string("location_detect_now", language: appLanguage)) {
                    manager.detectLocation()
                }
            }
        }
    }

    private var title: String {
        if manager.locationState == .detecting {
            return Translations.string("location_detecting", language: appLanguage)
        }
        let place = detectedPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !place.isEmpty { return place }
        // A fix whose reverse geocode failed is still a usable fix — it just has to be
        // labelled with its coordinates.
        if let fix = DeviceLocation.load() { return fix.displayName }
        return Translations.string("location_not_detected", language: appLanguage)
    }

    private var subtitle: String? {
        guard detectedAt > 0 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Translations.locale(appLanguage))
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let stamp = formatter.string(from: Date(timeIntervalSince1970: detectedAt))
        return Translations.string("location_updated", language: appLanguage) + " "
            + Translations.localizedNumber(stamp, numberFormat: numberFormat)
    }
}

/// The failure the app cannot retry its way out of, with the route out of it.
///
/// A denial is surfaced the same way the notifications pane surfaces its own: silently
/// swallowing it would leave the user pressing a button that can never work.
struct LocationProblemBanner: View {
    let appLanguage: String
    @EnvironmentObject var manager: PrayerManager

    var body: some View {
        switch manager.locationState {
        case .denied:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(Translations.string("location_denied", language: appLanguage))
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(Translations.string("location_open_settings", language: appLanguage)) {
                    Self.openLocationPrivacySettings()
                }
                .controlSize(.small)
            }
        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Text(Translations.string("location_failed", language: appLanguage))
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        case .idle, .detecting:
            EmptyView()
        }
    }

    static func openLocationPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// The settings-window version: the mode picker, then whichever source is active.
struct LocationSourceSection: View {
    let appLanguage: String
    @Binding var selectedCityRaw: String

    @EnvironmentObject var manager: PrayerManager
    @AppStorage(DeviceLocation.Keys.mode) private var storedMode = LocationMode.city.rawValue
    @AppStorage(DeviceLocation.Keys.followDevice) private var followDevice = false

    private var mode: LocationMode { LocationMode.from(storedMode) }

    var body: some View {
        SettingsStackedRow(title: Translations.string("location_source", language: appLanguage)) {
            LocationModePicker(appLanguage: appLanguage)
        }

        SettingsDivider()

        if mode == .city {
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                CitySearchPicker(selectedCityRaw: $selectedCityRaw, appLanguage: appLanguage)
            }
        } else {
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                DeviceLocationStatus(appLanguage: appLanguage)
                if manager.locationState == .denied || manager.locationState == .failed {
                    LocationProblemBanner(appLanguage: appLanguage)
                }
            }

            SettingsDivider()

            SettingsRow(title: Translations.string("location_follow", language: appLanguage),
                        subtitle: Translations.string("location_follow_hint", language: appLanguage)) {
                Toggle("", isOn: $followDevice)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
