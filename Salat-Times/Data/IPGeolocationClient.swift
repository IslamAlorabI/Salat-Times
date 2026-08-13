
import Foundation
import os

/// Where the Mac is, worked out from its public IP address.
///
/// This exists because CoreLocation cannot always answer. A Mac with no GPS positions
/// itself by scanning nearby Wi-Fi networks through CoreWLAN — so on a machine where
/// CoreWLAN enumerates no interface (a desktop on Ethernet with Wi-Fi off, or a Hackintosh
/// whose Wi-Fi driver presents the card as an Ethernet device), `locationd` has no source
/// at all. It reports `kCLErrorLocationUnknown` and then simply never calls back.
///
/// **This is a fallback and is never as good as a real fix.** An ISP's egress can be a long
/// way from its customer: measured against a known-good position, both providers below
/// answered with towns roughly 75 km away, enough to move Maghrib three minutes early.
/// That is why the result is flagged `isApproximate` all the way through to the settings
/// window — someone looking at these times deserves to know they were derived from a
/// network route rather than from where the Mac actually is.
nonisolated struct IPGeolocationClient: Sendable {
    enum ClientError: LocalizedError {
        case allProvidersFailed

        var errorDescription: String? {
            switch self {
            case .allProvidersFailed: return "No IP geolocation provider could be reached"
            }
        }
    }

    /// Tried in order. There are two of them because free providers do fail: ipapi.co,
    /// the obvious first choice, answered 429 "RateLimited" on the very first request
    /// made while building this.
    private static let providers: [Provider] = [
        Provider(name: "ipwho.is",
                 url: "https://ipwho.is/",
                 decode: { try JSONDecoder().decode(IPWhoIsResponse.self, from: $0).location }),
        Provider(name: "geojs.io",
                 url: "https://get.geojs.io/v1/ip/geo.json",
                 decode: { try JSONDecoder().decode(GeoJSResponse.self, from: $0).location }),
    ]

    private struct Provider: Sendable {
        let name: String
        let url: String
        /// Each provider spells its payload differently — geojs returns the coordinates as
        /// strings, ipwho.is as numbers — so the shape stays with the provider.
        let decode: @Sendable (Data) throws -> DeviceLocation?
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        // Short: this only runs after CoreLocation has already kept the user waiting.
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        // An IP location is worth exactly as much as the moment it was fetched.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    func locate() async throws -> DeviceLocation {
        for provider in Self.providers {
            do {
                guard let url = URL(string: provider.url) else { continue }
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    Log.data.error("\(provider.name, privacy: .public) returned HTTP \(http.statusCode)")
                    continue
                }
                guard let location = try provider.decode(data) else {
                    Log.data.error("\(provider.name, privacy: .public) returned no usable coordinates")
                    continue
                }
                Log.data.notice("Approximate location from \(provider.name, privacy: .public)")
                return location
            } catch {
                Log.data.error("\(provider.name, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        throw ClientError.allProvidersFailed
    }
}

// MARK: - Provider payloads

/// `nonisolated`, like every other model type here: the project sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it the `Decodable` conformance
/// is main-actor-isolated and cannot be used from the decoding closures above — a warning
/// today and an error in the Swift 6 language mode.
private nonisolated struct IPWhoIsResponse: Decodable {
    let success: Bool?
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case success, latitude, longitude, city
        case countryCode = "country_code"
    }

    var location: DeviceLocation? {
        guard success != false, let latitude, let longitude,
              DeviceLocation.isValid(latitude: latitude, longitude: longitude) else { return nil }
        return DeviceLocation(latitude: latitude,
                              longitude: longitude,
                              placeName: city ?? "",
                              countryCode: countryCode ?? "",
                              isApproximate: true)
    }
}

private nonisolated struct GeoJSResponse: Decodable {
    /// Strings, not numbers — this provider returns `"30.4581"`.
    let latitude: String?
    let longitude: String?
    let city: String?
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, city
        case countryCode = "country_code"
    }

    var location: DeviceLocation? {
        guard let latitude = latitude.flatMap(Double.init),
              let longitude = longitude.flatMap(Double.init),
              DeviceLocation.isValid(latitude: latitude, longitude: longitude) else { return nil }
        return DeviceLocation(latitude: latitude,
                              longitude: longitude,
                              placeName: city ?? "",
                              countryCode: countryCode ?? "",
                              isApproximate: true)
    }
}
