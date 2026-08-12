
import Foundation

// Moved out of PrayerManager: these are plain response models, shared by the
// popover header and (later) the calendar window and widget.

nonisolated struct HijriDate: Codable, Sendable, Equatable {
    let date: String
    let day: String
    let month: HijriMonth
    let year: String
    let weekday: HijriWeekday
}

nonisolated struct HijriMonth: Codable, Sendable, Equatable {
    let number: Int
    let en: String
    let ar: String
}

nonisolated struct HijriWeekday: Codable, Sendable, Equatable {
    let en: String
    let ar: String
}
