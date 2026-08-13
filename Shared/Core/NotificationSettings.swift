
import Foundation
import UserNotifications

// Notification preferences and sounds. In Core rather than the manager so the
// scheduler — and the behaviour checks — don't have to pull in SwiftUI.

// MARK: - Notification Sound Options
nonisolated enum NotificationSound: String, CaseIterable, Identifiable {
    case defaultSound = "default"
    case glass = "Glass"
    case ping = "Ping"
    case hero = "Hero"
    case submarine = "Submarine"
    case purr = "Purr"
    case basso = "Basso"
    case blow = "Blow"
    case funk = "Funk"
    case sosumi = "Sosumi"

    var id: String { rawValue }

    func displayName(language: String) -> String {
        Translations.string("sound_\(rawValue.lowercased())", language: language)
    }

    var notificationSound: UNNotificationSound {
        if self == .defaultSound {
            return .default
        }
        // macOS system sounds live in /System/Library/Sounds/
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(rawValue).aiff"))
    }
}

// MARK: - Prayer Notification Settings Helper
nonisolated struct PrayerNotificationSettings {
    static let prayers = PrayerKey.notifiable.map(\.rawValue)

    static func isEnabled(for prayer: String) -> Bool {
        SharedStore.defaults.object(forKey: "notification_\(prayer)_enabled") as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool, for prayer: String) {
        SharedStore.defaults.set(enabled, forKey: "notification_\(prayer)_enabled")
    }

    static func sound(for prayer: String) -> NotificationSound {
        let rawValue = SharedStore.defaults.string(forKey: "notification_\(prayer)_sound") ?? "default"
        return NotificationSound(rawValue: rawValue) ?? .defaultSound
    }

    static func setSound(_ sound: NotificationSound, for prayer: String) {
        SharedStore.defaults.set(sound.rawValue, forKey: "notification_\(prayer)_sound")
    }
}
