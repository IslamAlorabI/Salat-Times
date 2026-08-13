
import SwiftUI
import AppKit
import CoreLocation

// The location controls, shared by the settings window and the first-launch sheet so the
// two cannot drift into offering different things.
//
// The mode is an ordinary preference: writing it is the whole mechanism, because
// `PrayerSettings.load` reads it and the debounced diff in `PrayerManager` refetches. The
// `manager` calls below are real actions rather than settings echoes — asking CoreLocation
// for a fix is what puts the system permission prompt on screen, so it has to be started
// by a person, and there is nothing to detect until someone asks.

/// City ↔ device ↔ a point picked by hand, as a segmented control.
struct LocationModePicker: View {
    let appLanguage: String
    @EnvironmentObject var manager: PrayerManager
    @AppStorage(DeviceLocation.Keys.mode) private var storedMode = LocationMode.city.rawValue

    var body: some View {
        Picker("", selection: Binding(
            get: { LocationMode.from(storedMode) },
            set: { mode in
                switch mode {
                case .city: manager.useCityLocation()
                case .device: manager.useDeviceLocation()
                case .manual: manager.useManualLocation()
                }
            }
        )) {
            Text(Translations.string("location_choose_city", language: appLanguage)).tag(LocationMode.city)
            Text(Translations.string("location_use_device", language: appLanguage)).tag(LocationMode.device)
            Text(Translations.string("location_custom", language: appLanguage)).tag(LocationMode.manual)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// The hand-picked point: what it is, and the way to change it.
///
/// Nothing here re-detects or expires — a point the user chose stays put until they choose
/// another one, which is the whole difference between this and `DeviceLocationStatus`.
struct ManualLocationStatus: View {
    let appLanguage: String

    @EnvironmentObject var manager: PrayerManager
    // Read for their change notifications as much as their values: `@AppStorage` is what
    // redraws this row when the picker stores a new point.
    @AppStorage(LocationKeys.manual.placeName) private var pinName = ""
    @AppStorage(LocationKeys.manual.latitude) private var pinLatitude = 0.0
    @AppStorage(LocationKeys.manual.longitude) private var pinLongitude = 0.0
    @State private var isPickingOnMap = false

    /// `(0, 0)` is a real place, so absence is absence of the stored keys — which is what
    /// `DeviceLocation.load` checks. The `@AppStorage` values above only trigger the read.
    private var point: DeviceLocation? {
        _ = (pinName, pinLatitude, pinLongitude)
        return DeviceLocation.load(keys: .manual)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                if let point {
                    Text(point.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(DeviceLocation.coordinateLabel(latitude: point.latitude,
                                                        longitude: point.longitude))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(Translations.string("location_no_point", language: appLanguage))
                        .font(.system(size: 13, weight: .medium))
                    Text(Translations.string("location_no_point_hint", language: appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Button(Translations.string("location_pick_on_map", language: appLanguage)) {
                isPickingOnMap = true
            }
        }
        .sheet(isPresented: $isPickingOnMap) {
            MapLocationPicker(
                appLanguage: appLanguage,
                // Opens on the chosen point, or on wherever the app currently thinks it
                // is — the city or the last fix — rather than on the middle of the ocean.
                initialCoordinate: CLLocationCoordinate2D(
                    latitude: point?.latitude ?? manager.settings.latitude,
                    longitude: point?.longitude ?? manager.settings.longitude),
                onCancel: { isPickingOnMap = false },
                onChoose: { coordinate, name in
                    isPickingOnMap = false
                    manager.setManualLocation(latitude: coordinate.latitude,
                                              longitude: coordinate.longitude,
                                              preferredName: name)
                })
        }
    }
}

/// What was detected, when, and the button to do it again.
struct DeviceLocationStatus: View {
    let appLanguage: String
    /// The sheet has no room for a timestamp under the name; the settings pane does.
    var showsTimestamp = true

    @EnvironmentObject var manager: PrayerManager
    @AppStorage(LocationKeys.device.placeName) private var detectedPlace = ""
    @AppStorage(LocationKeys.device.updatedAt) private var detectedAt = 0.0
    @AppStorage(LocationKeys.device.isApproximate) private var isApproximate = false
    @AppStorage("numberFormat") private var numberFormat = "western"

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    // An IP-derived location is worth minutes of prayer time, so it says
                    // so on the row itself rather than only in a footnote.
                    if isApproximate && detectedAt > 0 && manager.locationState != .detecting {
                        Text(Translations.string("location_approximate_short", language: appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .foregroundStyle(.orange)
                    }
                }
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
        if let fix = DeviceLocation.load(keys: .device) { return fix.displayName }
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
    @AppStorage(LocationKeys.device.isApproximate) private var isApproximate = false
    @AppStorage(LocationKeys.device.updatedAt) private var detectedAt = 0.0

    private var mode: LocationMode { LocationMode.from(storedMode) }
    private var isDetecting: Bool { manager.locationState == .detecting }

    var body: some View {
        SettingsStackedRow(title: Translations.string("location_source", language: appLanguage)) {
            LocationModePicker(appLanguage: appLanguage)
        }

        SettingsDivider()

        switch mode {
        case .city:
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                CitySearchPicker(selectedCityRaw: $selectedCityRaw, appLanguage: appLanguage)
            }
        case .manual:
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                ManualLocationStatus(appLanguage: appLanguage)
            }
        case .device:
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                DeviceLocationStatus(appLanguage: appLanguage)
                if manager.locationState == .denied || manager.locationState == .failed {
                    LocationProblemBanner(appLanguage: appLanguage)
                }
                if isApproximate && !isDetecting {
                    Text(Translations.string("location_approximate", language: appLanguage))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
