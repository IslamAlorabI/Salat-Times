
import Foundation

nonisolated struct CalendarResponse: Codable, Sendable {
    let code: Int
    let data: [PrayerData]
}

/// Talks to api.aladhan.com. A whole month per request, which is what lets the app
/// run for weeks on one round trip.
nonisolated struct AladhanClient: Sendable {
    enum ClientError: LocalizedError {
        case badResponse(Int)
        case emptyMonth

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): return "Aladhan returned HTTP \(code)"
            case .emptyMonth: return "Aladhan returned an empty month"
            }
        }
    }

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        // Prayer times for a given month never change; let the URL cache help.
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)
    }

    func month(year: Int, month: Int, settings: PrayerSettings) async throws -> PrayerTimetable {
        var components = URLComponents(string: "https://api.aladhan.com/v1/calendar/\(year)/\(month)")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: "\(settings.latitude)"),
            URLQueryItem(name: "longitude", value: "\(settings.longitude)"),
            URLQueryItem(name: "method", value: "\(settings.method)"),
            URLQueryItem(name: "school", value: "\(settings.school)"),
            URLQueryItem(name: "latitudeAdjustmentMethod", value: "\(settings.latitudeAdjustment)"),
            URLQueryItem(name: "midnightMode", value: "\(settings.midnightMode)"),
        ]

        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ClientError.badResponse(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(CalendarResponse.self, from: data)
        guard let first = decoded.data.first else { throw ClientError.emptyMonth }

        var days: [String: DayTimings] = [:]
        for entry in decoded.data {
            let stamp = entry.date.gregorian.dateStamp
            days[stamp] = DayTimings(dateStamp: stamp,
                                     minutes: DayTimings.parseMinutes(from: entry.timings),
                                     hijri: entry.date.hijri)
        }

        return PrayerTimetable(timeZoneID: first.meta.timezone, days: days)
    }
}
