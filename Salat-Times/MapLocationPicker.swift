
import SwiftUI
import MapKit
import AppKit

// Picking a point by hand: a map to click, a search field, and the two numbers.
//
// MapKit is used rather than a web map because it is part of the OS — no key, no quota,
// no dependency, and it draws in the system's language and appearance for free. The one
// thing it needs is the outgoing-network entitlement the app already has for Aladhan.
//
// Everything here ends at `PrayerManager.setManualLocation`, which writes the coordinate
// to `UserDefaults` and stops. The refetch, the notification rotation and the menu bar all
// follow from the debounced settings diff, exactly as they do for a detected fix.

/// The sheet: map on top, search and coordinates below.
struct MapLocationPicker: View {
    let appLanguage: String
    /// Where to open the map. The point already chosen, or wherever the app currently
    /// thinks it is — starting at (0, 0) in the Gulf of Guinea would be useless.
    let initialCoordinate: CLLocationCoordinate2D
    let onCancel: () -> Void
    /// The chosen coordinate and, when it came from a search result, the name the user
    /// actually picked — more specific than what reverse geocoding would return.
    let onChoose: (CLLocationCoordinate2D, String) -> Void

    @State private var coordinate: CLLocationCoordinate2D
    @State private var chosenName = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var searchText = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    /// Bumped whenever the coordinate changes from something *other* than a click on the
    /// map, which is when the map should follow. A click already put the pin where the
    /// user pointed; re-centring on it would yank the map out from under them.
    @State private var recenterToken = 0

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    init(appLanguage: String,
         initialCoordinate: CLLocationCoordinate2D,
         onCancel: @escaping () -> Void,
         onChoose: @escaping (CLLocationCoordinate2D, String) -> Void) {
        self.appLanguage = appLanguage
        self.initialCoordinate = initialCoordinate
        self.onCancel = onCancel
        self.onChoose = onChoose
        _coordinate = State(initialValue: initialCoordinate)
        _latitudeText = State(initialValue: Self.format(initialCoordinate.latitude))
        _longitudeText = State(initialValue: Self.format(initialCoordinate.longitude))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ZStack(alignment: .top) {
                MapCoordinatePicker(coordinate: $coordinate, recenterToken: recenterToken) { picked in
                    // A point off the map is the user's own choice of place, so any name
                    // carried over from a search result no longer describes it.
                    chosenName = ""
                    latitudeText = Self.format(picked.latitude)
                    longitudeText = Self.format(picked.longitude)
                }
                if !results.isEmpty {
                    resultsList
                        .padding(10)
                }
            }
            .frame(minHeight: 300)

            Divider()
            footer
        }
        .frame(width: 640, height: 620)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header: search

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(Translations.string("location_search_places", language: appLanguage),
                      text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit { search() }
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                    results = []
                    searchFailed = false
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button(Translations.string("search_action", language: appLanguage)) { search() }
                .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var resultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button {
                        select(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "—")
                                .font(.system(size: 13, weight: .medium))
                            if let subtitle = Self.subtitle(for: item) {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
        .frame(maxWidth: 320, maxHeight: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
        .shadow(radius: 8, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer: coordinates and the decision

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Translations.string("location_map_hint", language: appLanguage))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                coordinateField(title: Translations.string("location_latitude", language: appLanguage),
                                text: $latitudeText)
                coordinateField(title: Translations.string("location_longitude", language: appLanguage),
                                text: $longitudeText)
                Spacer(minLength: 0)
            }

            if typedCoordinate == nil {
                Label(Translations.string("location_coordinates_invalid", language: appLanguage),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else if searchFailed {
                Text(Translations.string("location_no_results", language: appLanguage))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(Translations.string("cancel", language: appLanguage), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(Translations.string("location_use_point", language: appLanguage)) {
                    guard let point = typedCoordinate else { return }
                    onChoose(point, chosenName)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(typedCoordinate == nil)
            }
        }
        .padding(14)
    }

    private func coordinateField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            // Deliberately plain `TextField` + `Double(_:)`: coordinates are typed and
            // pasted with a dot, whatever the app's language, and a locale-aware number
            // formatter would reject "31.2" for an Arabic or German user.
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .onSubmit { applyTypedCoordinate() }
                .onChange(of: text.wrappedValue) { _ in applyTypedCoordinate() }
        }
    }

    /// The coordinate currently in the two fields, or `nil` when it is not one.
    private var typedCoordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(latitudeText.trimmingCharacters(in: .whitespaces)),
              let longitude = Double(longitudeText.trimmingCharacters(in: .whitespaces)),
              DeviceLocation.isValid(latitude: latitude, longitude: longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Typing moves the pin, but only once the numbers are a real place — otherwise the
    /// map would jump about while a longitude is half-typed.
    private func applyTypedCoordinate() {
        guard let point = typedCoordinate else { return }
        guard point.latitude != coordinate.latitude || point.longitude != coordinate.longitude else { return }
        coordinate = point
        chosenName = ""
        recenterToken += 1
    }

    // MARK: - Search

    /// `MKLocalSearch` is the free, keyless counterpart to the map itself. It is biased
    /// towards what is on screen but not limited to it, so searching for a city on the
    /// other side of the world still finds it.
    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchFailed = false

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 20, longitudeDelta: 20))

        MKLocalSearch(request: request).start { response, _ in
            Task { @MainActor in
                isSearching = false
                let items = response?.mapItems ?? []
                results = Array(items.prefix(12))
                searchFailed = items.isEmpty
            }
        }
    }

    private func select(_ item: MKMapItem) {
        let point = item.placemark.coordinate
        coordinate = point
        chosenName = item.name ?? item.placemark.locality ?? ""
        latitudeText = Self.format(point.latitude)
        longitudeText = Self.format(point.longitude)
        recenterToken += 1
        results = []
        searchText = item.name ?? searchText
    }

    private static func subtitle(for item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { $0 != item.name }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Four decimals: the precision `requestFingerprint` prints, and finer than the ~1.1 km
    /// the coordinate is rounded to when it is stored. Western digits and a dot, always —
    /// this is a value that gets typed and pasted, not a number that gets read.
    private static func format(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

/// `MKMapView` wrapped for SwiftUI, because SwiftUI's own `Map` cannot report where the
/// user clicked until macOS 14 and the app's floor is 13.
struct MapCoordinatePicker: NSViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    /// Changes when the coordinate came from search or the text fields, which is the only
    /// time the map should re-centre itself.
    let recenterToken: Int
    let onClick: (CLLocationCoordinate2D) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsZoomControls = true
        map.showsCompass = true
        map.isPitchEnabled = false
        map.isRotateEnabled = false

        let click = NSClickGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handleClick(_:)))
        // Without this the recogniser swallows the press MKMapView needs for panning and
        // double-click zoom, and the map goes dead.
        click.delaysPrimaryMouseButtonEvents = false
        map.addGestureRecognizer(click)
        context.coordinator.map = map

        map.addAnnotation(context.coordinator.pin)
        context.coordinator.pin.coordinate = coordinate
        map.setRegion(MKCoordinateRegion(center: coordinate,
                                         span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)),
                      animated: false)
        context.coordinator.lastRecenterToken = recenterToken
        return map
    }

    func updateNSView(_ map: MKMapView, context: Context) {
        // The coordinator outlives every `MapCoordinatePicker` value SwiftUI makes, so it
        // is handed the current one rather than keeping the one it was created with.
        context.coordinator.parent = self
        context.coordinator.pin.coordinate = coordinate
        guard context.coordinator.lastRecenterToken != recenterToken else { return }
        context.coordinator.lastRecenterToken = recenterToken
        // Keeps whatever zoom the user has settled on; only the centre moves.
        map.setCenter(coordinate, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject {
        let pin = MKPointAnnotation()
        weak var map: MKMapView?
        var lastRecenterToken = 0
        var parent: MapCoordinatePicker

        init(_ parent: MapCoordinatePicker) { self.parent = parent }

        @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
            guard let map else { return }
            let point = recognizer.location(in: map)
            let picked = map.convert(point, toCoordinateFrom: map)
            guard DeviceLocation.isValid(latitude: picked.latitude, longitude: picked.longitude) else { return }
            pin.coordinate = picked
            parent.coordinate = picked
            parent.onClick(picked)
        }
    }
}
