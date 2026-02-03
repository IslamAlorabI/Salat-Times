
import SwiftUI
import AppKit

struct ContentView: View    {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) var colorScheme
    
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    @AppStorage("numberFormat") private var numberFormat = "western"
    
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
                            .background(Color.accentColor.opacity(0.8))
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
                            .background(Color.accentColor.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(Translations.string("refresh_data", language: appLanguage))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            
            if let hijri = manager.hijriDate {
                HStack {
                    Spacer()
                    getHijriDateView(hijri)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.5))
                .id(numberFormat)
            }
            
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
                    PrayerRow(name: getPrayerName("Fajr"), time: formatTime(manager.timings["Fajr"]), icon: "sunrise", color: getPrayerColor("Fajr"), isUpcoming: upcomingPrayer == "Fajr")
                    PrayerRow(name: getPrayerName("Sunrise"), time: formatTime(manager.timings["Sunrise"]), icon: "sunrise.fill", color: getPrayerColor("Sunrise"), isUpcoming: upcomingPrayer == "Sunrise")
                    PrayerRow(name: getPrayerName("Dhuhr"), time: formatTime(manager.timings["Dhuhr"]), icon: "sun.max.fill", color: getPrayerColor("Dhuhr"), isUpcoming: upcomingPrayer == "Dhuhr")
                    PrayerRow(name: getPrayerName("Asr"), time: formatTime(manager.timings["Asr"]), icon: "sun.min.fill", color: getPrayerColor("Asr"), isUpcoming: upcomingPrayer == "Asr")
                    PrayerRow(name: getPrayerName("Maghrib"), time: formatTime(manager.timings["Maghrib"]), icon: "sunset.fill", color: getPrayerColor("Maghrib"), isUpcoming: upcomingPrayer == "Maghrib")
                    PrayerRow(name: getPrayerName("Isha"), time: formatTime(manager.timings["Isha"]), icon: "moon.stars.fill", color: getPrayerColor("Isha"), isUpcoming: upcomingPrayer == "Isha")
                }
                .padding(.vertical, 12)
                .id(numberFormat)
            }
            
            Divider()
            
            HStack {
                Text("v3.0")
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
                    .foregroundColor(.accentColor)
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
                    .foregroundColor(.accentColor)
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
    
    @ViewBuilder
    func getHijriDateView(_ hijri: HijriDate) -> some View {
        let monthName = Translations.hijriMonthName(hijri.month.number, language: appLanguage)
        let yearLabel = Translations.string("hijri_year_label", language: appLanguage)
        let suffix = Translations.string("hijri_migration_suffix", language: appLanguage)
        let localizedDay = Translations.localizedNumber(hijri.day, numberFormat: numberFormat)
        let localizedYear = Translations.localizedNumber(hijri.year, numberFormat: numberFormat)
        
        HStack(spacing: 4) {
            // Day and Month
            HStack(spacing: 3) {
                Text(localizedDay)
                Text(monthName)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            
            // Year and Suffix
            HStack(spacing: 3) {
                Text(localizedYear)
                if !yearLabel.isEmpty {
                    Text(yearLabel)
                }
                Text(suffix)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.accentColor)
        }
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
        
        var formattedTime: String
        if is24HourFormat {
            formattedTime = time
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let date = formatter.date(from: time) {
                formatter.dateFormat = "h:mm a"
                formatter.locale = Locale(identifier: Translations.locale(appLanguage))
                formattedTime = formatter.string(from: date)
            } else {
                formattedTime = time
            }
        }
        
        return Translations.localizedNumber(formattedTime, numberFormat: numberFormat)
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
    
    func getPrayerColor(_ key: String) -> Color {
        let isDark = colorScheme == .dark
        
        switch key {
        case "Fajr":
            // Purple
            return isDark ? Color(red: 0.6, green: 0.5, blue: 1.0) : Color(red: 0.4, green: 0.3, blue: 0.7)
            
        case "Sunrise":
            // Orange-Yellow
            return isDark ? Color(red: 1.0, green: 0.7, blue: 0.4) : Color(red: 0.8, green: 0.4, blue: 0.0)
            
        case "Dhuhr":
            // Yellow
            return isDark ? Color(red: 1.0, green: 0.9, blue: 0.4) : Color(red: 0.8, green: 0.6, blue: 0.0)
            
        case "Asr":
            // Orange
            return isDark ? Color(red: 1.0, green: 0.6, blue: 0.2) : Color(red: 0.9, green: 0.4, blue: 0.0)
            
        case "Maghrib":
            // Red-Orange
            return isDark ? Color(red: 1.0, green: 0.4, blue: 0.3) : Color(red: 0.8, green: 0.2, blue: 0.1)
            
        case "Isha":
            // Blue
            return isDark ? Color(red: 0.4, green: 0.6, blue: 1.0) : Color(red: 0.1, green: 0.3, blue: 0.7)
            
        default:
            return .primary
        }
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
        Color.accentColor
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(highlightColor)
                }
            } else {
                Text(time)
                    .font(.system(size: 16, weight: .bold))
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
