
import Foundation
import CoreLocation
import SwiftUI
import Combine
import UserNotifications
import AppKit

// MARK: - Notification Sound Options
enum NotificationSound: String, CaseIterable, Identifiable {
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
        let names: [String: [String: String]] = [
            "default": [
                "ar": "الافتراضي", "en": "Default", "ru": "По умолчанию", "id": "Default",
                "tr": "Varsayılan", "ur": "طے شدہ", "fa": "پیش‌فرض", "de": "Standard"
            ],
            "Glass": [
                "ar": "زجاج", "en": "Glass", "ru": "Стекло", "id": "Kaca",
                "tr": "Cam", "ur": "شیشہ", "fa": "شیشه", "de": "Glas"
            ],
            "Ping": [
                "ar": "رنين", "en": "Ping", "ru": "Пинг", "id": "Ping",
                "tr": "Ping", "ur": "پنگ", "fa": "پینگ", "de": "Ping"
            ],
            "Hero": [
                "ar": "بطولي", "en": "Hero", "ru": "Герой", "id": "Pahlawan",
                "tr": "Kahraman", "ur": "ہیرو", "fa": "قهرمان", "de": "Held"
            ],
            "Submarine": [
                "ar": "غواصة", "en": "Submarine", "ru": "Подводная лодка", "id": "Kapal selam",
                "tr": "Denizaltı", "ur": "آبدوز", "fa": "زیردریایی", "de": "U-Boot"
            ],
            "Purr": [
                "ar": "خرخرة", "en": "Purr", "ru": "Мурлыканье", "id": "Dengkur",
                "tr": "Mırıldama", "ur": "خرخراہٹ", "fa": "خرخر", "de": "Schnurren"
            ],
            "Basso": [
                "ar": "جهير", "en": "Basso", "ru": "Бассо", "id": "Basso",
                "tr": "Basso", "ur": "باسو", "fa": "باس", "de": "Basso"
            ],
            "Blow": [
                "ar": "نفخة", "en": "Blow", "ru": "Дуновение", "id": "Tiup",
                "tr": "Üfleme", "ur": "پھونک", "fa": "دم", "de": "Blasen"
            ],
            "Funk": [
                "ar": "فانك", "en": "Funk", "ru": "Фанк", "id": "Funk",
                "tr": "Funk", "ur": "فنک", "fa": "فانک", "de": "Funk"
            ],
            "Sosumi": [
                "ar": "سوسومي", "en": "Sosumi", "ru": "Сосуми", "id": "Sosumi",
                "tr": "Sosumi", "ur": "سوسومی", "fa": "سوسومی", "de": "Sosumi"
            ]
        ]
        return names[self.rawValue]?[language] ?? names[self.rawValue]?["en"] ?? self.rawValue
    }
    
    var notificationSound: UNNotificationSound {
        if self == .defaultSound {
            return .default
        }
        // macOS system sounds are in /System/Library/Sounds/
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(rawValue).aiff"))
    }
}

// MARK: - Prayer Notification Settings Helper
struct PrayerNotificationSettings {
    static let prayers = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
    
    static func isEnabled(for prayer: String) -> Bool {
        UserDefaults.standard.object(forKey: "notification_\(prayer)_enabled") as? Bool ?? true
    }
    
    static func setEnabled(_ enabled: Bool, for prayer: String) {
        UserDefaults.standard.set(enabled, forKey: "notification_\(prayer)_enabled")
    }
    
    static func sound(for prayer: String) -> NotificationSound {
        let rawValue = UserDefaults.standard.string(forKey: "notification_\(prayer)_sound") ?? "default"
        return NotificationSound(rawValue: rawValue) ?? .defaultSound
    }
    
    static func setSound(_ sound: NotificationSound, for prayer: String) {
        UserDefaults.standard.set(sound.rawValue, forKey: "notification_\(prayer)_sound")
    }
}

struct PrayerResponse: Codable, Sendable {
    let code: Int
    let status: String
    let data: PrayerData
}

struct PrayerData: Codable, Sendable {
    let timings: [String: String]
    let meta: PrayerMeta
}

struct PrayerMeta: Codable, Sendable {
    let timezone: String
}

class PrayerManager: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    @Published var timings: [String: String] = [:]
    @Published var isLoading = true
    @Published var city: String = "Loading..."
    @Published var errorMessage: String? = nil
    @Published var countdownText: String = ""
    @Published var upcomingPrayerName: String = ""
    @Published var menuBarTitle: String = "Salat Times"
    
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var countdownTimer: Timer?
    private var languageObserver: NSObjectProtocol?
    private var lastLanguage: String = ""
    
    override init() {
        super.init()
        locationManager.delegate = self
        notificationCenter.delegate = self
        
        lastLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        
        loadSavedCity()
        requestNotificationPermission()
        startCountdownTimer()
        observeLanguageChanges()
    }
    
    deinit {
        countdownTimer?.invalidate()
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func observeLanguageChanges() {
        // Observe UserDefaults changes
        languageObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
            // Only update if language actually changed
            if currentLanguage != self.lastLanguage {
                self.lastLanguage = currentLanguage
                self.updateCountdown()
            }
        }
    }
    
    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        }
    }
    
    func schedulePrayerNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let prayerIds = requests.filter { $0.identifier.hasPrefix("prayer_") }.map { $0.identifier }
            let legacyTestIds = requests.filter { $0.identifier.hasPrefix("test_prayer_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: prayerIds + legacyTestIds)
            
            DispatchQueue.main.async {
                self.schedulePrayerNotificationsInternal()
            }
        }
    }
    
    private func schedulePrayerNotificationsInternal() {
        let calendar = Calendar.current
        let today = Date()
        
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        
        for (key, timeString) in timings {
            guard ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"].contains(key) else { continue }
            
            // Check if notification is enabled for this prayer
            guard PrayerNotificationSettings.isEnabled(for: key) else {
                print("⏭️ Notification disabled for \(key), skipping")
                continue
            }
            
            let timeComponents = timeString.split(separator: ":").compactMap({ Int($0) })
            guard timeComponents.count == 2 else { continue }
            
            let hour = timeComponents[0]
            let minute = timeComponents[1]
            
            var components = calendar.dateComponents([.year, .month, .day], from: today)
            components.hour = hour
            components.minute = minute
            components.second = 0
            
            guard var prayerDate = calendar.date(from: components) else { continue }
            
            if prayerDate < today {
                prayerDate = calendar.date(byAdding: .day, value: 1, to: prayerDate) ?? prayerDate
            }
            
            let content = UNMutableNotificationContent()
            let prayerTranslationKey = "prayer_\(key.lowercased())"
            let prayerName = Translations.string(prayerTranslationKey, language: appLanguage)
            let title = Translations.string("prayer_time", language: appLanguage)
            let bodyFormat = Translations.string("prayer_time_body", language: appLanguage)
            content.title = title
            content.body = String(format: bodyFormat, prayerName)
            
            // Use custom sound for this prayer
            let soundSetting = PrayerNotificationSettings.sound(for: key)
            content.sound = soundSetting.notificationSound
            content.badge = 1
            
            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let identifier = "prayer_\(key)_\(prayerDate.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification for \(key): \(error.localizedDescription)")
                } else {
                    print("✅ Scheduled notification for \(prayerName) at \(timeString) with sound: \(soundSetting.rawValue)")
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func loadSavedCity() {
        self.isLoading = true
        self.errorMessage = nil
        
        let savedCityRaw = UserDefaults.standard.string(forKey: "selectedCityRaw") ?? City.cairo.rawValue
        
        if let cityEnum = City.allCases.first(where: { $0.rawValue == savedCityRaw }) {
            self.city = cityEnum.rawValue
            let coords = cityEnum.coordinates
            print("🌍 Loading manual city data: \(cityEnum.rawValue)")
            fetchPrayerTimes(lat: coords.latitude, lon: coords.longitude)
        } else {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.first != nil else { return }
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ GPS Error: \(error.localizedDescription)")
        loadSavedCity()
    }
    
    func fetchPrayerTimes(lat: Double, lon: Double) {
        let method = UserDefaults.standard.integer(forKey: "calculationMethod")
        let actualMethod = method == 0 ? 5 : method
        
        let urlString = "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=\(actualMethod)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if error != nil {
                DispatchQueue.main.async {
                    let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
                    self.errorMessage = Translations.string("check_internet", language: appLanguage)
                    self.isLoading = false
                }
                return
            }
            
            if let data = data {
                let decoder = JSONDecoder()
                if let decoded = try? decoder.decode(PrayerResponse.self, from: data) {
                    DispatchQueue.main.async {
                        self.timings = decoded.data.timings
                        self.isLoading = false
                        self.schedulePrayerNotifications()
                        self.updateCountdown()
                    }
                }
            }
        }.resume()
    }
    
    func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateCountdown()
            }
        }
        DispatchQueue.main.async {
            self.updateCountdown()
        }
    }
    
    func updateCountdown() {
        let calendar = Calendar.current
        let now = Date()
        let prayerOrder = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        var prayerDates: [(key: String, date: Date)] = []
        
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        
        for prayerKey in prayerOrder {
            guard let timeString = timings[prayerKey] else { continue }
            
            let timeComponents = timeString.split(separator: ":").compactMap({ Int($0) })
            guard timeComponents.count == 2 else { continue }
            
            let hour = timeComponents[0]
            let minute = timeComponents[1]
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            
            guard var prayerDate = calendar.date(from: components) else { continue }
            
            if prayerDate < now {
                prayerDate = calendar.date(byAdding: .day, value: 1, to: prayerDate) ?? prayerDate
            }
            
            prayerDates.append((key: prayerKey, date: prayerDate))
        }
        
        prayerDates.sort { $0.date < $1.date }
        
        guard let upcoming = prayerDates.first(where: { $0.date > now }) ?? prayerDates.first else {
            countdownText = ""
            upcomingPrayerName = ""
            menuBarTitle = "Salat Times"
            return
        }
        
        let timeRemaining = upcoming.date.timeIntervalSince(now)
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        
        let prayerTranslationKey = "prayer_\(upcoming.key.lowercased())"
        let prayerName = Translations.string(prayerTranslationKey, language: appLanguage)
        
        // Format countdown text based on language
        if hours > 0 {
            switch appLanguage {
            case "ar", "ur", "fa":
                countdownText = "\(hours)س \(minutes)د"
            case "ru":
                countdownText = "\(hours)ч \(minutes)м"
            case "id":
                countdownText = "\(hours)j \(minutes)m"
            case "tr":
                countdownText = "\(hours)s \(minutes)d"
            case "de":
                countdownText = "\(hours)h \(minutes)m"
            default:
                countdownText = "\(hours)h \(minutes)m"
            }
        } else {
            switch appLanguage {
            case "ar", "ur", "fa":
                countdownText = "\(minutes)د"
            case "ru":
                countdownText = "\(minutes)м"
            case "id":
                countdownText = "\(minutes)m"
            case "tr":
                countdownText = "\(minutes)d"
            case "de":
                countdownText = "\(minutes)m"
            default:
                countdownText = "\(minutes)m"
            }
        }
        
        upcomingPrayerName = prayerName
        
        // Update menu bar title
        if countdownText.isEmpty {
            menuBarTitle = "Salat Times"
        } else {
            menuBarTitle = "\(prayerName) -\(countdownText)"
        }
    }
}
