
import Foundation
import CoreLocation
import SwiftUI
import Combine
import UserNotifications

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
    @Published var city: String = "جاري التحميل..."
    @Published var errorMessage: String? = nil
    @Published var testPrayerTime: Date? = nil
    @Published var testPrayerName: String = ""
    
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        super.init()
        locationManager.delegate = self
        notificationCenter.delegate = self
        
        loadSavedCity()
        requestNotificationPermission()
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
        let savedTestTime = testPrayerTime
        let savedTestName = testPrayerName
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let prayerIdentifiers = requests.filter { $0.identifier.hasPrefix("prayer_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: prayerIdentifiers)
            
            DispatchQueue.main.async {
                self.schedulePrayerNotificationsInternal()
                if savedTestTime != nil, !savedTestName.isEmpty {
                    self.testPrayerTime = savedTestTime
                    self.testPrayerName = savedTestName
                    self.scheduleTestPrayerNotification()
                }
            }
        }
    }
    
    private func schedulePrayerNotificationsInternal() {
        let calendar = Calendar.current
        let today = Date()
        
        let prayerNames: [String: (ar: String, en: String)] = [
            "Fajr": ("الفجر", "Fajr"),
            "Dhuhr": ("الظهر", "Dhuhr"),
            "Asr": ("العصر", "Asr"),
            "Maghrib": ("المغرب", "Maghrib"),
            "Isha": ("العشاء", "Isha")
        ]
        
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        
        for (key, timeString) in timings {
            guard let prayerInfo = prayerNames[key] else { continue }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
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
            let prayerName = appLanguage == "ar" ? prayerInfo.ar : prayerInfo.en
            content.title = appLanguage == "ar" ? "حان وقت الصلاة" : "Prayer Time"
            content.body = appLanguage == "ar" ? "حان وقت صلاة \(prayerName)" : "It's time for \(prayerName) prayer"
            content.sound = .default
            content.badge = 1
            
            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let identifier = "prayer_\(key)_\(prayerDate.timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling notification for \(key): \(error.localizedDescription)")
                } else {
                    print("✅ Scheduled notification for \(prayerName) at \(timeString)")
                }
            }
        }
    }
    
    func scheduleTestPrayerNotification() {
        guard let testTime = testPrayerTime, !testPrayerName.isEmpty else { return }
        
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
        
        let content = UNMutableNotificationContent()
        content.title = appLanguage == "ar" ? "اختبار: حان وقت الصلاة" : "Test: Prayer Time"
        content.body = appLanguage == "ar" ? "اختبار: حان وقت صلاة \(testPrayerName)" : "Test: It's time for \(testPrayerName) prayer"
        content.sound = .default
        content.badge = 1
        
        let calendar = Calendar.current
        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: testTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let identifier = "test_prayer_\(testTime.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.add(request) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Error scheduling test prayer notification: \(error.localizedDescription)")
            } else {
                print("✅ Scheduled test prayer notification for \(self.testPrayerName) at \(testTime)")
            }
        }
    }
    
    func addTestPrayer(name: String, time: Date) {
        testPrayerName = name
        testPrayerTime = time
        scheduleTestPrayerNotification()
    }
    
    func removeTestPrayer() {
        testPrayerName = ""
        testPrayerTime = nil
        notificationCenter.getPendingNotificationRequests { requests in
            let testIdentifiers = requests.filter { $0.identifier.hasPrefix("test_prayer_") }.map { $0.identifier }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: testIdentifiers)
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
            print("🌍 تحميل بيانات المدينة اليدوية: \(cityEnum.rawValue)")
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
                    self.errorMessage = "تأكد من الاتصال بالإنترنت"
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
                    }
                }
            }
        }.resume()
    }
}
