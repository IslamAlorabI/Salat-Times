
import SwiftUI
import AppKit
import Combine

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
                VStack(alignment: .leading, spacing: 4) {
                    if let hijri = manager.hijriDate {
                        getHijriHeaderView(hijri)
                            .id(numberFormat)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(getCityName())
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    getGregorianDateView()
                        .id(numberFormat)
                    
                    // Green only when these times came fresh from the server. Cached or
                    // stale data still displays, but the dot says so.
                    let isFresh = manager.lastUpdatedFromServer != nil && !manager.isServingStaleData
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFresh ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(Translations.string(isFresh ? "server_synced" : "offline", language: appLanguage))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)
            
            Divider()
            
            if !manager.isLoading && manager.errorMessage == nil {
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    CountdownView(
                        upcoming: PrayerScheduleCalculator.next(after: context.date, in: manager.events),
                        now: context.date,
                        numberFormat: numberFormat,
                        appLanguage: appLanguage
                    )
                }
                .padding(.vertical, 16)
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
                let upcomingKey = PrayerScheduleCalculator.next(after: Date(), in: manager.events)?.key
                VStack(spacing: 4) {
                    ForEach(manager.todayEvents.filter { !$0.key.isNightMarker }) { event in
                        PrayerRow(name: event.name(language: appLanguage),
                                  time: manager.formattedTime(event.date),
                                  icon: event.key.systemImageName,
                                  color: getPrayerColor(event.key),
                                  isUpcoming: upcomingKey == event.key)
                    }
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
    func getHijriHeaderView(_ hijri: HijriDate) -> some View {
        let monthName = Translations.hijriMonthName(hijri.month.number, language: appLanguage)
        let localizedDay = Translations.localizedNumber(hijri.day, numberFormat: numberFormat)
        let localizedYear = Translations.localizedNumber(hijri.year, numberFormat: numberFormat)
        
        HStack(spacing: 4) {
            Text(localizedDay)
                .foregroundColor(.primary)
            Text(monthName)
                .foregroundColor(.primary)
            Text(localizedYear)
                .foregroundColor(.accentColor)
        }
        .font(.system(size: 18, weight: .bold, design: .rounded))
    }
    
    func getGregorianDateView() -> some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Translations.locale(appLanguage))
        formatter.dateFormat = "d MMMM yyyy"
        let dateString = formatter.string(from: Date())
        let localizedDate = Translations.localizedNumber(dateString, numberFormat: numberFormat)
        
        return Text(localizedDate)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
    }
    
    func getPrayerColor(_ key: PrayerKey) -> Color {
        let isDark = colorScheme == .dark

        switch key {
        case .fajr:
            // Purple
            return isDark ? Color(red: 0.6, green: 0.5, blue: 1.0) : Color(red: 0.4, green: 0.3, blue: 0.7)

        case .sunrise:
            // Orange-Yellow
            return isDark ? Color(red: 1.0, green: 0.7, blue: 0.4) : Color(red: 0.8, green: 0.4, blue: 0.0)

        case .dhuhr:
            // Yellow
            return isDark ? Color(red: 1.0, green: 0.9, blue: 0.4) : Color(red: 0.8, green: 0.6, blue: 0.0)

        case .asr:
            // Orange
            return isDark ? Color(red: 1.0, green: 0.6, blue: 0.2) : Color(red: 0.9, green: 0.4, blue: 0.0)

        case .maghrib:
            // Red-Orange
            return isDark ? Color(red: 1.0, green: 0.4, blue: 0.3) : Color(red: 0.8, green: 0.2, blue: 0.1)

        case .isha:
            // Blue
            return isDark ? Color(red: 0.4, green: 0.6, blue: 1.0) : Color(red: 0.1, green: 0.3, blue: 0.7)

        case .midnight, .lastThird:
            // Muted indigo — these mark the night rather than a prayer.
            return isDark ? Color(red: 0.55, green: 0.55, blue: 0.85) : Color(red: 0.35, green: 0.35, blue: 0.6)
        }
    }
}

struct CountdownView: View {
    let upcoming: PrayerEvent?
    let now: Date
    let numberFormat: String
    let appLanguage: String

    var body: some View {
        if let upcoming {
            let time = Countdown.from(now, to: upcoming)
            VStack(spacing: 8) {
                Text(Translations.string("prayer_after_format", language: appLanguage)
                    .replacingOccurrences(of: "%@", with: upcoming.name(language: appLanguage)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(formatTimeUnit(time.hours))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(Translations.string("hours_short", language: appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(":")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .opacity(0.5)
                    
                    VStack(spacing: 2) {
                        Text(formatTimeUnit(time.minutes))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(Translations.string("minutes_short", language: appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(":")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .opacity(0.5)
                    
                    VStack(spacing: 2) {
                        Text(formatTimeUnit(time.seconds))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(Translations.string("seconds_short", language: appLanguage))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
        }
    }
    
    private func formatTimeUnit(_ value: Int) -> String {
        let formatted = String(format: "%02d", value)
        return Translations.localizedNumber(formatted, numberFormat: numberFormat)
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
