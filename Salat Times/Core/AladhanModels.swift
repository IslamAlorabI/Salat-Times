
import Foundation

// Response shapes for api.aladhan.com. Kept in Core so the data layer does not
// have to pull in the manager (and therefore SwiftUI) to decode a response.

nonisolated struct PrayerResponse: Codable, Sendable {
    let code: Int
    let status: String
    let data: PrayerData
}

nonisolated struct PrayerData: Codable, Sendable {
    let timings: [String: String]
    let date: DateInfo
    let meta: PrayerMeta
}

nonisolated struct PrayerMeta: Codable, Sendable {
    let timezone: String
}

nonisolated struct DateInfo: Codable, Sendable {
    let hijri: HijriDate
    let gregorian: GregorianDate
}

nonisolated struct GregorianDate: Codable, Sendable {
    /// `DD-MM-YYYY`, per the API's own `format` field.
    let date: String

    /// Normalised to `yyyy-MM-dd` so it can key a `PrayerTimetable`.
    var dateStamp: String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[2])-\(parts[1])-\(parts[0])"
    }
}
