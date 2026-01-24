
import SwiftUI
import AppKit

struct ContentView: View    {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                if Translations.isRTL(appLanguage) {
                    Button(action: {
                        manager.loadSavedCity()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(Translations.string("refresh_data", language: appLanguage))
                    
                    Spacer()
                }
                
                VStack(alignment: Translations.isRTL(appLanguage) ? .trailing : .leading, spacing: 4) {
                    Text(Translations.string("prayer_times_today", language: appLanguage))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .multilineTextAlignment(Translations.isRTL(appLanguage) ? .trailing : .leading)
                    
                    Text(getCityName())
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(Translations.isRTL(appLanguage) ? .trailing : .leading)
                }
                
                if !Translations.isRTL(appLanguage) {
                    Spacer()
                    
                    Button(action: {
                        manager.loadSavedCity()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(Translations.string("refresh_data", language: appLanguage))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            
            Divider()
            
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
                    Button(Translations.string("retry", language: appLanguage)) {
                        manager.loadSavedCity()
                    }
                    Spacer()
                }
            } else {
                let upcomingPrayer = getUpcomingPrayer()
                VStack(spacing: 4) {
                    PrayerRow(name: getPrayerName("Fajr"), time: formatTime(manager.timings["Fajr"]), icon: "sunrise", color: Color(red: 0.4, green: 0.3, blue: 0.7), isUpcoming: upcomingPrayer == "Fajr")
                    PrayerRow(name: getPrayerName("Sunrise"), time: formatTime(manager.timings["Sunrise"]), icon: "sunrise.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2), isUpcoming: upcomingPrayer == "Sunrise")
                    PrayerRow(name: getPrayerName("Dhuhr"), time: formatTime(manager.timings["Dhuhr"]), icon: "sun.max.fill", color: Color(red: 1.0, green: 0.8, blue: 0.0), isUpcoming: upcomingPrayer == "Dhuhr")
                    PrayerRow(name: getPrayerName("Asr"), time: formatTime(manager.timings["Asr"]), icon: "sun.min.fill", color: Color(red: 1.0, green: 0.5, blue: 0.0), isUpcoming: upcomingPrayer == "Asr")
                    PrayerRow(name: getPrayerName("Maghrib"), time: formatTime(manager.timings["Maghrib"]), icon: "sunset.fill", color: Color(red: 1.0, green: 0.3, blue: 0.2), isUpcoming: upcomingPrayer == "Maghrib")
                    PrayerRow(name: getPrayerName("Isha"), time: formatTime(manager.timings["Isha"]), icon: "moon.stars.fill", color: Color(red: 0.3, green: 0.4, blue: 0.8), isUpcoming: upcomingPrayer == "Isha")
                }
                .padding(.vertical, 12)
            }
            
            Divider()
            
            HStack {
                Text("v1.5")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                
                Button {
                    openWindow(id: "settings")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        if let window = NSApplication.shared.windows.first(where: { $0.title == Translations.string("settings", language: appLanguage) }) {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                        Text(Translations.string("settings", language: appLanguage))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.link)
                
                Spacer()
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text(Translations.string("quit", language: appLanguage))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.link)
            }
            .padding(10)
            .background(.thinMaterial)
        }
        .frame(width: 300)
        .fixedSize(horizontal: true, vertical: true)
        .background(.ultraThinMaterial)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        .onAppear {
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<ContentView> }) ?? false }) {
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = true
                }
            }
        }
    }
    
    func getCityName() -> String {
        if let cityEnum = City.allCases.first(where: { $0.rawValue == manager.city }) {
            return cityEnum.getName(language: appLanguage)
        }
        return manager.city
    }
    
    func getPrayerName(_ key: String) -> String {
        switch key {
        case "Fajr": return Translations.string("prayer_fajr", language: appLanguage)
        case "Sunrise": return Translations.string("prayer_sunrise", language: appLanguage)
        case "Dhuhr": return Translations.string("prayer_dhuhr", language: appLanguage)
        case "Asr": return Translations.string("prayer_asr", language: appLanguage)
        case "Maghrib": return Translations.string("prayer_maghrib", language: appLanguage)
        case "Isha": return Translations.string("prayer_isha", language: appLanguage)
        default: return key
        }
    }
    
    func formatTime(_ time: String?) -> String {
        guard let time = time else { return "--:--" }
        if is24HourFormat { return time }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: time) {
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: Translations.locale(appLanguage))
            return formatter.string(from: date)
        }
        return time
    }
    
    func getUpcomingPrayer() -> String? {
        let calendar = Calendar.current
        let now = Date()
        let prayerOrder = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]
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
            
            if prayerDate < now {
                prayerDate = calendar.date(byAdding: .day, value: 1, to: prayerDate) ?? prayerDate
            }
            
            prayerDates.append((key: prayerKey, date: prayerDate))
        }
        
        prayerDates.sort { $0.date < $1.date }
        return prayerDates.first(where: { $0.date > now })?.key ?? prayerDates.first?.key
    }
}

struct PrayerRow: View {
    let name: String
    let time: String
    let icon: String
    let color: Color
    let isUpcoming: Bool
    @Environment(\.layoutDirection) var layoutDirection
    
    private var highlightColor: Color {
        Color(red: 0.2, green: 0.6, blue: 1.0)
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
            }
        )
        .cornerRadius(isUpcoming ? 8 : 6)
        .padding(.horizontal, 8)
        .shadow(color: isUpcoming ? highlightColor.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: isUpcoming)
    }
}
