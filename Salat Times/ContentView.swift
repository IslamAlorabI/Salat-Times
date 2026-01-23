//
//  Untitled.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    
    // قراءة الإعدادات
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- الهيدر ---
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appLanguage == "ar" ? "أوقات الصلاة اليوم" : "Prayer Times Today")
                        .font(.system(size: 18, weight: .bold, design: .rounded)) // كبرنا الخط
                    
                    Text(getCityName())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // الزر المدمج (تحديث + موقع)
                Button(action: {
                    manager.loadSavedCity()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath") // أيقونة تحديث
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(appLanguage == "ar" ? "تحديث البيانات" : "Refresh Data")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.2)) // خلفية خفيفة للهيدر
            
            Divider()
            
            // --- المحتوى ---
            if manager.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
            } else if let error = manager.errorMessage {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                    Button(appLanguage == "ar" ? "إعادة المحاولة" : "Retry") {
                        manager.loadSavedCity()
                    }
                    Spacer()
                }
            } else {
                // قائمة الصلوات
                VStack(spacing: 4) { // تقليل المسافات بين الأسطر
                    PrayerRow(name: getPrayerName("Fajr"), time: formatTime(manager.timings["Fajr"]), icon: "sunrise")
                    PrayerRow(name: getPrayerName("Sunrise"), time: formatTime(manager.timings["Sunrise"]), icon: "sunrise.fill")
                    PrayerRow(name: getPrayerName("Dhuhr"), time: formatTime(manager.timings["Dhuhr"]), icon: "sun.max.fill")
                    PrayerRow(name: getPrayerName("Asr"), time: formatTime(manager.timings["Asr"]), icon: "sun.min.fill")
                    PrayerRow(name: getPrayerName("Maghrib"), time: formatTime(manager.timings["Maghrib"]), icon: "sunset.fill")
                    PrayerRow(name: getPrayerName("Isha"), time: formatTime(manager.timings["Isha"]), icon: "moon.stars.fill")
                 //   PrayerRow(name: getPrayerName("Lastthird"), time: formatTime(manager.timings["Lastthird"]), icon: "sparkles")
                }
                .padding(.vertical, 12)
            }
            
            Spacer() // لملء أي فراغ متبقي بذكاء
            
            Divider()
            
            // --- الفوتر ---
            HStack {
                Text("v1.1")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(appLanguage == "ar" ? "الإعدادات" : "Settings") {
                    openWindow(id: "settings")
                }
                .buttonStyle(.link)
                .font(.system(size: 12, weight: .medium))
            }
            .padding(10)
            .background(Color.black.opacity(0.1))
        }
        // تعديل الحجم لإزالة المساحة الزرقاء (الفراغ)
        .frame(width: 300, height: 360)
        .background(.ultraThinMaterial)
    }
    
    // دالة لجلب اسم المدينة حسب اللغة
    func getCityName() -> String {
        if let cityEnum = City.allCases.first(where: { $0.rawValue == manager.city }) {
            return appLanguage == "ar" ? cityEnum.arabicName : cityEnum.englishName
        }
        return manager.city
    }
    
    // دالة لترجمة أسماء الصلوات
    func getPrayerName(_ key: String) -> String {
        if appLanguage == "en" { return key } // إرجاع الاسم الإنجليزي كما هو
        switch key {
        case "Fajr": return "الفجر"
        case "Sunrise": return "الشروق"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
       // case "Lastthird": return "الثلث الأخير"
        default: return key
        }
    }
    
    // دالة لتنسيق الوقت (12/24)
    func formatTime(_ time: String?) -> String {
        guard let time = time else { return "--:--" }
        if is24HourFormat { return time }
        
        // تحويل من 24 لـ 12
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: appLanguage == "ar" ? "ar" : "en")
            return formatter.string(from: date)
        }
        return time
    }
}

// تصميم الصف الواحد (محدث)
struct PrayerRow: View {
    let name: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue.opacity(0.8)) // لون أزرق هادئ للأيقونات
            
            Text(name)
                .font(.system(size: 16, weight: .medium)) // تكبير الخط
            
            Spacer()
            
            Text(time)
                .font(.system(size: 16, weight: .bold, design: .monospaced)) // تكبير خط الوقت
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05)) // خلفية خفيفة جداً لكل سطر
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}
