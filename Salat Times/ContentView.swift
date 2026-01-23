//
//  Untitled.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI
import AppKit

struct ContentView: View    {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    
    // قراءة الإعدادات
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    
    var body: some View {
        VStack(spacing: 0) {
            
            // --- الهيدر ---
            HStack {
                if appLanguage == "ar" {
                    // الزر المدمج (تحديث + موقع) - في البداية للعربية
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
                    
                    Spacer()
                }
                
                VStack(alignment: appLanguage == "ar" ? .trailing : .leading, spacing: 4) {
                    Text(appLanguage == "ar" ? "أوقات الصلاة اليوم" : "Prayer Times Today")
                        .font(.system(size: 18, weight: .bold, design: .rounded)) // كبرنا الخط
                        .multilineTextAlignment(appLanguage == "ar" ? .trailing : .leading)
                    
                    Text(getCityName())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(appLanguage == "ar" ? .trailing : .leading)
                }
                
                if appLanguage != "ar" {
                    Spacer()
                    
                    // الزر المدمج (تحديث + موقع) - في النهاية للإنجليزية
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial) // خلفية شفافة مع تأثير الضبابية
            
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
                let upcomingPrayer = getUpcomingPrayer()
                VStack(spacing: 4) { // تقليل المسافات بين الأسطر
                    PrayerRow(name: getPrayerName("Fajr"), time: formatTime(manager.timings["Fajr"]), icon: "sunrise", color: Color(red: 0.4, green: 0.3, blue: 0.7), isUpcoming: upcomingPrayer == "Fajr")
                    PrayerRow(name: getPrayerName("Sunrise"), time: formatTime(manager.timings["Sunrise"]), icon: "sunrise.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2), isUpcoming: upcomingPrayer == "Sunrise")
                    PrayerRow(name: getPrayerName("Dhuhr"), time: formatTime(manager.timings["Dhuhr"]), icon: "sun.max.fill", color: Color(red: 1.0, green: 0.8, blue: 0.0), isUpcoming: upcomingPrayer == "Dhuhr")
                    PrayerRow(name: getPrayerName("Asr"), time: formatTime(manager.timings["Asr"]), icon: "sun.min.fill", color: Color(red: 1.0, green: 0.5, blue: 0.0), isUpcoming: upcomingPrayer == "Asr")
                    PrayerRow(name: getPrayerName("Maghrib"), time: formatTime(manager.timings["Maghrib"]), icon: "sunset.fill", color: Color(red: 1.0, green: 0.3, blue: 0.2), isUpcoming: upcomingPrayer == "Maghrib")
                    PrayerRow(name: getPrayerName("Isha"), time: formatTime(manager.timings["Isha"]), icon: "moon.stars.fill", color: Color(red: 0.3, green: 0.4, blue: 0.8), isUpcoming: upcomingPrayer == "Isha")
                 //   PrayerRow(name: getPrayerName("Lastthird"), time: formatTime(manager.timings["Lastthird"]), icon: "sparkles")
                }
                .padding(.vertical, 12)
            }
            
            Divider()
            
            // --- الفوتر ---
            HStack {
                Text("v1.1")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(appLanguage == "ar" ? "الإعدادات" : "Settings") {
                    openWindow(id: "settings")
                    // تفعيل التطبيق وجعل نافذة الإعدادات في المقدمة
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        if let window = NSApplication.shared.windows.first(where: { $0.title == "الإعدادات" || $0.title == "Settings" }) {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 12, weight: .medium))
            }
            .padding(10)
            .background(.thinMaterial)
        }
        // تعديل الحجم لإزالة المساحة الزرقاء (الفراغ)
        .frame(width: 300)
        .fixedSize(horizontal: true, vertical: true)
        .background(.ultraThinMaterial)
        .environment(\.layoutDirection, appLanguage == "ar" ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: appLanguage == "ar" ? "ar" : "en"))
        .onAppear {
            // تفعيل الشفافية لنافذة MenuBarExtra
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<ContentView> }) ?? false }) {
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = true
                }
            }
        }
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
    
    // دالة لتحديد الصلاة القادمة
    func getUpcomingPrayer() -> String? {
        let calendar = Calendar.current
        let now = Date()
        
        // ترتيب الصلوات حسب الوقت
        let prayerOrder = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
        
        // تحويل الأوقات إلى Date objects
        var prayerDates: [(key: String, date: Date)] = []
        
        for prayerKey in prayerOrder {
            guard let timeString = manager.timings[prayerKey] else { continue }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            
            let timeComponents = timeString.split(separator: ":").compactMap({ Int($0) })
            guard timeComponents.count == 2 else { continue }
            
            let hour = timeComponents[0]
            let minute = timeComponents[1]
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            
            guard var prayerDate = calendar.date(from: components) else { continue }
            
            // إذا كان وقت الصلاة قد مضى اليوم، نضيف يوم
            if prayerDate < now {
                prayerDate = calendar.date(byAdding: .day, value: 1, to: prayerDate) ?? prayerDate
            }
            
            prayerDates.append((key: prayerKey, date: prayerDate))
        }
        
        // ترتيب حسب الوقت
        prayerDates.sort { $0.date < $1.date }
        
        // إرجاع أول صلاة بعد الوقت الحالي
        return prayerDates.first(where: { $0.date > now })?.key ?? prayerDates.first?.key
    }
}

// تصميم الصف الواحد (محدث)
struct PrayerRow: View {
    let name: String
    let time: String
    let icon: String
    let color: Color
    let isUpcoming: Bool
    @Environment(\.layoutDirection) var layoutDirection
    
    // لون التمييز للصلاة القادمة - أزرق فاتح أنيق
    private var highlightColor: Color {
        Color(red: 0.2, green: 0.6, blue: 1.0) // أزرق فاتح أنيق
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(isUpcoming ? highlightColor : color.opacity(0.7))
            
            Text(name)
                .font(.system(size: 16, weight: isUpcoming ? .semibold : .medium))
                .foregroundColor(isUpcoming ? highlightColor : .primary)
            
            Spacer()
            
            if isUpcoming {
                HStack(spacing: 4) {
                    Image(systemName: layoutDirection == .rightToLeft ? "arrow.left.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(highlightColor)
                    Text(time)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(highlightColor)
                }
            } else {
                Text(time)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isUpcoming ? 8 : 6)
        .background(
            Group {
                if isUpcoming {
                    // خلفية متدرجة أنيقة للصلاة القادمة مع الشفافية
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial.opacity(0.6))
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        highlightColor.opacity(0.15),
                                        highlightColor.opacity(0.10)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(highlightColor.opacity(0.4), lineWidth: 1.5)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.ultraThinMaterial.opacity(0.4))
                }
            }
        )
        .cornerRadius(isUpcoming ? 8 : 6)
        .padding(.horizontal, 8)
        .shadow(color: isUpcoming ? highlightColor.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isUpcoming)
    }
}
