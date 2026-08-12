
import Foundation

/// The prayers and derived times the app knows about.
///
/// `rawValue` is deliberately the Aladhan API's own key. The same string is also the
/// fragment in `notification_<Key>_enabled` / `notification_<Key>_sound`, so these
/// cases can be introduced without migrating any stored preference.
nonisolated enum PrayerKey: String, CaseIterable, Codable, Sendable {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
    case midnight = "Midnight"
    case lastThird = "Lastthird"

    /// The five prayers plus sunrise: everything the API treats as a real prayer time
    /// and everything the user can be notified about.
    static let notifiable: [PrayerKey] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    /// Display order in the popover and the monthly table.
    static let displayOrder: [PrayerKey] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha, .midnight, .lastThird]

    /// Midnight and the last third mark the night, not a prayer; they are shown but
    /// never notified and never counted as "the next prayer".
    var isNightMarker: Bool {
        self == .midnight || self == .lastThird
    }

    /// Dhuhr is Jumu'ah on Fridays. Resolving this once, at event construction, means
    /// the popover, notifications, monthly table and widget all inherit it for free.
    func translationKey(isFriday: Bool) -> String {
        if self == .dhuhr && isFriday { return "prayer_jumuah" }
        switch self {
        case .lastThird: return "prayer_qiyam"
        default: return "prayer_\(rawValue.lowercased())"
        }
    }

    var systemImageName: String {
        switch self {
        case .fajr: return "sunrise"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        case .midnight: return "moon.fill"
        case .lastThird: return "moon.zzz.fill"
        }
    }
}
