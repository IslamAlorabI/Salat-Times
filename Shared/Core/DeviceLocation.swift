
import Foundation
import CoreLocation

/// Where the app takes its coordinates from.
///
/// Stored as a string rather than a `Bool` so a source can be added without migrating
/// anyone's preferences — which is exactly how `manual` arrived after `city` and `device`.
nonisolated enum LocationMode: String, Sendable, CaseIterable {
    /// A city picked from the built-in list. The default, and the only mode before 3.1.
    case city
    /// Coordinates from CoreLocation.
    case device
    /// A point the user chose by hand: dropped on the map, searched for, or typed as a
    /// latitude and longitude. Nothing ever moves it — unlike `device`, which re-detects.
    case manual

    /// Absent or unrecognised reads as `city`: a preference written by a future build
    /// must never leave an existing one without a location at all.
    static func from(_ raw: String?) -> LocationMode {
        LocationMode(rawValue: raw ?? "") ?? .city
    }
}

/// The `UserDefaults` keys one stored coordinate occupies.
///
/// There are two sets, and they are deliberately disjoint. A detected fix and a
/// hand-picked pin are different answers to different questions, so re-detecting must not
/// overwrite a pin the user placed on purpose, and switching between the two modes must
/// not lose either. The names are on disk — rename one and every existing install loses
/// that location.
nonisolated struct LocationKeys: Sendable {
    let latitude: String
    let longitude: String
    let placeName: String
    let countryCode: String
    let updatedAt: String
    let isApproximate: String

    /// What CoreLocation (or the IP fallback) last produced. Unchanged since 3.1.
    static let device = LocationKeys(
        latitude: "deviceLatitude",
        longitude: "deviceLongitude",
        placeName: "devicePlaceName",
        countryCode: "deviceCountryCode",
        updatedAt: "deviceLocationUpdatedAt",
        isApproximate: "deviceLocationIsApproximate")

    /// The point the user picked on the map or typed in. `isApproximate` is stored for
    /// symmetry only — a chosen point is never approximate.
    static let manual = LocationKeys(
        latitude: "manualLatitude",
        longitude: "manualLongitude",
        placeName: "manualPlaceName",
        countryCode: "manualCountryCode",
        updatedAt: "manualLocationUpdatedAt",
        isApproximate: "manualLocationIsApproximate")
}

/// One coordinate the app can work from — a fix from CoreLocation or a point the user
/// picked by hand — reduced to what the app actually needs and rounded to something a
/// prayer timetable can be keyed by.
///
/// Kept in `Core/` — and free of CoreLocation's manager types — so the rounding and the
/// storage contract can be checked without a GUI or a device.
nonisolated struct DeviceLocation: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    /// Reverse-geocoded and already in the app's language, or empty when geocoding
    /// failed — the coordinates are what matter, the name is only ever shown.
    var placeName: String
    /// ISO country code, or empty. Stored for exactly one reason: to notice that the
    /// user has crossed a border, which is when the calculation method should follow.
    var countryCode: String
    var updatedAt: Date
    /// True when this came from the IP fallback rather than CoreLocation — tens of
    /// kilometres out is normal for an ISP egress, which is worth minutes of prayer time.
    /// Carried all the way to the settings window so it is never mistaken for a real fix.
    var isApproximate: Bool

    /// Coordinates are stored rounded to this many decimals — roughly 1.1 km.
    ///
    /// Not cosmetic, and not a privacy gesture. `PrayerSettings.requestFingerprint`
    /// prints coordinates to four decimals and that fingerprint *is* the month cache's
    /// file name, so an unrounded fix would mint a new cache file and a new month
    /// request every time GPS wobbled by a few metres — which it does, indoors,
    /// constantly. Across 1 km prayer times move by a couple of seconds.
    static let precisionDecimals = 2

    static func rounded(_ value: Double) -> Double {
        let factor = pow(10.0, Double(precisionDecimals))
        return (value * factor).rounded() / factor
    }

    /// A coordinate CoreLocation could plausibly have produced. `(0, 0)` is a real place
    /// in the Gulf of Guinea, so it is *not* treated as "unset" — absence is absence of
    /// the key, which is why `load` checks for the object rather than for a zero.
    static func isValid(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    init(latitude: Double,
         longitude: Double,
         placeName: String = "",
         countryCode: String = "",
         updatedAt: Date = Date(),
         isApproximate: Bool = false) {
        self.latitude = Self.rounded(latitude)
        self.longitude = Self.rounded(longitude)
        self.placeName = placeName
        self.countryCode = countryCode
        self.updatedAt = updatedAt
        self.isApproximate = isApproximate
    }

    /// What the rest of the app calls this place. Falls back to the coordinates
    /// themselves, because a nameless location still has to label a menu bar popover, a
    /// printed schedule and a CSV file name.
    var displayName: String {
        let trimmed = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return trimmed }
        return Self.coordinateLabel(latitude: latitude, longitude: longitude)
    }

    /// Deliberately western digits and ASCII: this is a fallback label that also ends up
    /// in an exported file name.
    static func coordinateLabel(latitude: Double, longitude: Double) -> String {
        String(format: "%.2f%@, %.2f%@",
               abs(latitude), latitude >= 0 ? "N" : "S",
               abs(longitude), longitude >= 0 ? "E" : "W")
    }

    // MARK: - Storage

    /// The mode-level keys. The per-coordinate ones live in `LocationKeys`, because there
    /// is more than one coordinate stored at a time. Named here rather than spelled out
    /// at each call site so a view and the manager cannot drift apart on a typo.
    enum Keys {
        static let mode = "locationMode"
        /// Opt-in: re-detect at launch, on wake and when the day rolls over. Off by
        /// default, so location is read only when the user asks for it. Applies to
        /// `device` mode only — a hand-picked point is never re-detected.
        static let followDevice = "locationFollowsDevice"
    }

    static func load(from defaults: UserDefaults = SharedStore.defaults,
                     keys: LocationKeys = .device) -> DeviceLocation? {
        guard defaults.object(forKey: keys.latitude) != nil,
              defaults.object(forKey: keys.longitude) != nil else { return nil }

        let latitude = defaults.double(forKey: keys.latitude)
        let longitude = defaults.double(forKey: keys.longitude)
        // A corrupt or hand-edited coordinate must not reach a request URL.
        guard isValid(latitude: latitude, longitude: longitude) else { return nil }

        let stamp = defaults.double(forKey: keys.updatedAt)
        return DeviceLocation(
            latitude: latitude,
            longitude: longitude,
            placeName: defaults.string(forKey: keys.placeName) ?? "",
            countryCode: defaults.string(forKey: keys.countryCode) ?? "",
            updatedAt: stamp > 0 ? Date(timeIntervalSince1970: stamp) : .distantPast,
            isApproximate: defaults.bool(forKey: keys.isApproximate))
    }

    func save(to defaults: UserDefaults = SharedStore.defaults,
              keys: LocationKeys = .device) {
        defaults.set(latitude, forKey: keys.latitude)
        defaults.set(longitude, forKey: keys.longitude)
        defaults.set(placeName, forKey: keys.placeName)
        defaults.set(countryCode, forKey: keys.countryCode)
        defaults.set(updatedAt.timeIntervalSince1970, forKey: keys.updatedAt)
        defaults.set(isApproximate, forKey: keys.isApproximate)
    }

    /// The keys the given mode reads and writes, or `nil` for the city list — which has
    /// no stored coordinate at all, it has a `City`.
    static func keys(for mode: LocationMode) -> LocationKeys? {
        switch mode {
        case .city: return nil
        case .device: return .device
        case .manual: return .manual
        }
    }

    /// True when the two fixes would produce different prayer times — i.e. when they
    /// differ *after* rounding. Used to decide whether a new fix is worth a refetch.
    func isSamePlace(as other: DeviceLocation) -> Bool {
        latitude == other.latitude && longitude == other.longitude
    }
}

extension City {
    /// The listed city closest to a coordinate, by great-circle distance.
    ///
    /// Only ever used to *suggest* a calculation method for a detected location: the
    /// times themselves come from the real coordinates, never from the nearest city.
    static func nearest(toLatitude latitude: Double, longitude: Double) -> City {
        allCases.min { a, b in
            distance(from: (latitude, longitude), to: a) < distance(from: (latitude, longitude), to: b)
        } ?? .cairo
    }

    /// The calculation method of whichever listed city is closest — the same authority
    /// the app would have used had the user picked that city by hand.
    static func recommendedMethod(forLatitude latitude: Double, longitude: Double) -> Int {
        nearest(toLatitude: latitude, longitude: longitude).recommendedMethod
    }

    private static func distance(from point: (latitude: Double, longitude: Double), to city: City) -> Double {
        let coords = city.coordinates
        let earthRadius = 6_371.0
        let dLat = (coords.latitude - point.latitude) * .pi / 180
        let dLon = (coords.longitude - point.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(point.latitude * .pi / 180) * cos(coords.latitude * .pi / 180)
            * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}
