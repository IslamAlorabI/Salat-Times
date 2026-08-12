import SwiftUI
import CoreLocation
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("calculationMethod") private var method = 5
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    @AppStorage("numberFormat") private var numberFormat = "western"
    
    // Notification settings per prayer
    @AppStorage("notification_Fajr_enabled") private var fajrEnabled = true
    @AppStorage("notification_Sunrise_enabled") private var sunriseEnabled = true
    @AppStorage("notification_Dhuhr_enabled") private var dhuhrEnabled = true
    @AppStorage("notification_Asr_enabled") private var asrEnabled = true
    @AppStorage("notification_Maghrib_enabled") private var maghribEnabled = true
    @AppStorage("notification_Isha_enabled") private var ishaEnabled = true
    
    @AppStorage("notification_Fajr_sound") private var fajrSound = "default"
    @AppStorage("notification_Sunrise_sound") private var sunriseSound = "default"
    @AppStorage("notification_Dhuhr_sound") private var dhuhrSound = "default"
    @AppStorage("notification_Asr_sound") private var asrSound = "default"
    @AppStorage("notification_Maghrib_sound") private var maghribSound = "default"
    @AppStorage("notification_Isha_sound") private var ishaSound = "default"
    
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("reminderInterval") private var reminderInterval = 0
    @AppStorage("warningInterval") private var warningInterval = 0
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                
                GroupBox(label: Label(Translations.string("general", language: appLanguage), systemImage: "gearshape")) {
                    HStack {
                        Text(Translations.string("launch_at_login", language: appLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { newValue in
                                do {
                                    if newValue {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                } catch {
                                    print("Failed to update launch at login: \(error)")
                                    launchAtLogin = !newValue
                                }
                            }
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    HStack {
                        Text(Translations.string("refresh_data", language: appLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Button(action: {
                            manager.loadSavedCity()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                Text(Translations.string("refresh", language: appLanguage))
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label(Translations.string("languages", language: appLanguage), systemImage: "globe")) {
                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: 12) {
                        LanguageRadioButton(title: Translations.string("language_ar", language: "ar"), tag: "ar", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_en", language: "en"), tag: "en", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_ru", language: "ru"), tag: "ru", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_id", language: "id"), tag: "id", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_tr", language: "tr"), tag: "tr", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_ur", language: "ur"), tag: "ur", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_fa", language: "fa"), tag: "fa", selection: $appLanguage)
                        LanguageRadioButton(title: Translations.string("language_de", language: "de"), tag: "de", selection: $appLanguage)
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label(Translations.string("number_format", language: appLanguage), systemImage: "textformat.123")) {
                    HStack(spacing: 0) {
                        NumberFormatRadioButton(
                            title: Translations.string("numbers_western", language: appLanguage),
                            example: "123",
                            tag: "western",
                            selection: $numberFormat
                        )
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                        
                        NumberFormatRadioButton(
                            title: Translations.string("numbers_arabic", language: appLanguage),
                            example: "١٢٣",
                            tag: "arabic",
                            selection: $numberFormat
                        )
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                        
                        NumberFormatRadioButton(
                            title: Translations.string("numbers_persian", language: appLanguage),
                            example: "۱۲۳",
                            tag: "persian",
                            selection: $numberFormat
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label(Translations.string("location", language: appLanguage), systemImage: "location.fill")) {
                    CitySearchPicker(selectedCityRaw: $selectedCityRaw, appLanguage: appLanguage)
                }
                
                GroupBox(label: Label(Translations.string("calculation_method", language: appLanguage), systemImage: "function")) {
                    CalculationMethodPicker(selectedMethod: $method, appLanguage: appLanguage)
                }
                
                GroupBox(label: Label(Translations.string("time_format", language: appLanguage), systemImage: "clock")) {
                    HStack(spacing: 0) {
                        TimeFormatRadioButton(title: "24H (18:00)", isSelected: is24HourFormat) {
                            is24HourFormat = true
                        }
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                        
                        TimeFormatRadioButton(title: "12H (6:00 PM)", isSelected: !is24HourFormat) {
                            is24HourFormat = false
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label(Translations.string("prayer_reminder", language: appLanguage), systemImage: "bell.and.waves.left.and.right")) {
                    HStack {
                        Text(Translations.string("prayer_reminder", language: appLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $reminderInterval) {
                            Text(Translations.string("reminder_disabled", language: appLanguage)).tag(0)
                            Text(Translations.string("reminder_10_minutes", language: appLanguage)).tag(10)
                            Text(Translations.string("reminder_15_minutes", language: appLanguage)).tag(15)
                            Text(Translations.string("reminder_20_minutes", language: appLanguage)).tag(20)
                            Text(Translations.string("reminder_30_minutes", language: appLanguage)).tag(30)
                            Text(Translations.string("reminder_1_hour", language: appLanguage)).tag(60)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .padding(.vertical, 4)
                }
                
                GroupBox(label: Label(Translations.string("menu_bar_warning", language: appLanguage), systemImage: "exclamationmark.triangle")) {
                    HStack {
                        Text(Translations.string("menu_bar_warning", language: appLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $warningInterval) {
                            Text(Translations.string("warning_disabled", language: appLanguage)).tag(0)
                            Text(Translations.string("warning_10_minutes", language: appLanguage)).tag(10)
                            Text(Translations.string("warning_15_minutes", language: appLanguage)).tag(15)
                            Text(Translations.string("warning_20_minutes", language: appLanguage)).tag(20)
                            Text(Translations.string("warning_25_minutes", language: appLanguage)).tag(25)
                            Text(Translations.string("warning_30_minutes", language: appLanguage)).tag(30)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .padding(.vertical, 4)
                }

                
                GroupBox(label: Label(Translations.string("prayer_notifications", language: appLanguage), systemImage: "bell.badge")) {
                    VStack(spacing: 12) {
                        // Every toggle below is inert if macOS has notifications denied,
                        // and nothing else in the app would ever say so.
                        if manager.notificationAuthorization == .denied {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: Translations.isRTL(appLanguage) ? .trailing : .leading, spacing: 4) {
                                    Text(Translations.string("notifications_denied", language: appLanguage))
                                        .font(.system(size: 12))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button(Translations.string("open_system_settings", language: appLanguage)) {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }
                                    .buttonStyle(.link)
                                    .font(.system(size: 12))
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))

                            Divider()
                        }

                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_fajr", language: appLanguage),
                            icon: "sunrise",
                            isEnabled: $fajrEnabled,
                            soundRawValue: $fajrSound,
                            appLanguage: appLanguage
                        )
                        
                        Divider()
                        
                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_sunrise", language: appLanguage),
                            icon: "sunrise.fill",
                            isEnabled: $sunriseEnabled,
                            soundRawValue: $sunriseSound,
                            appLanguage: appLanguage
                        )
                        
                        Divider()
                        
                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_dhuhr", language: appLanguage),
                            icon: "sun.max.fill",
                            isEnabled: $dhuhrEnabled,
                            soundRawValue: $dhuhrSound,
                            appLanguage: appLanguage
                        )
                        
                        Divider()
                        
                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_asr", language: appLanguage),
                            icon: "sun.min.fill",
                            isEnabled: $asrEnabled,
                            soundRawValue: $asrSound,
                            appLanguage: appLanguage
                        )
                        
                        Divider()
                        
                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_maghrib", language: appLanguage),
                            icon: "sunset.fill",
                            isEnabled: $maghribEnabled,
                            soundRawValue: $maghribSound,
                            appLanguage: appLanguage
                        )
                        
                        Divider()
                        
                        PrayerNotificationRow(
                            prayerName: Translations.string("prayer_isha", language: appLanguage),
                            icon: "moon.stars.fill",
                            isEnabled: $ishaEnabled,
                            soundRawValue: $ishaSound,
                            appLanguage: appLanguage
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Spacer()
                    Link(destination: URL(string: "https://github.com/IslamAlorabI")!) {
                        Text("Made with ♥︎ by Islam AlorabI - 2026")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .padding()
        }
        .frame(minWidth: 420, maxWidth: 500, minHeight: 750)
        .background(.regularMaterial)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        .onChange(of: selectedCityRaw) { newValue in
            if let city = City(rawValue: newValue) {
                method = city.recommendedMethod
            }
            manager.loadSavedCity()
        }
        .onChange(of: method) { _ in manager.loadSavedCity() }
        .onChange(of: numberFormat) { _ in manager.updateCountdown() }
        // Reschedule notifications when any notification setting changes
        .onChange(of: fajrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: sunriseEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: dhuhrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: asrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: maghribEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: ishaEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: fajrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: sunriseSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: dhuhrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: asrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: maghribSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: ishaSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: reminderInterval) { _ in manager.schedulePrayerNotifications() }
    }
}

// MARK: - City Search Picker Component
struct CitySearchPicker: View {
    @Binding var selectedCityRaw: String
    let appLanguage: String
    @State private var searchText = ""
    @State private var isShowingPopover = false
    
    private var selectedCity: City? {
        City(rawValue: selectedCityRaw)
    }
    
    private var filteredCities: [City] {
        if searchText.isEmpty {
            return City.allCases
        }
        return City.allCases.filter { city in
            city.getName(language: appLanguage).localizedCaseInsensitiveContains(searchText) ||
            city.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func citiesForContinent(_ continent: Continent) -> [City] {
        filteredCities.filter { $0.continent == continent }
    }
    
    var body: some View {
        HStack {
            if let city = selectedCity {
                VStack(alignment: Translations.isRTL(appLanguage) ? .trailing : .leading, spacing: 2) {
                    Text(city.getName(language: appLanguage))
                        .font(.system(size: 13, weight: .medium))
                    Text(city.continent.getName(language: appLanguage))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                isShowingPopover.toggle()
            } label: {
                Text(Translations.string("change", language: appLanguage))
                    .font(.system(size: 12))
            }
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(Translations.string("search", language: appLanguage), text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    List {
                        ForEach(Continent.allCases) { continent in
                            let cities = citiesForContinent(continent)
                            if !cities.isEmpty {
                                Section(header: Text(continent.getName(language: appLanguage))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)) {
                                    ForEach(cities) { city in
                                        Button {
                                            selectedCityRaw = city.rawValue
                                            isShowingPopover = false
                                            searchText = ""
                                        } label: {
                                            HStack {
                                                Text(city.getName(language: appLanguage))
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                if city.rawValue == selectedCityRaw {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(.accentColor)
                                                        .font(.system(size: 12, weight: .semibold))
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
                .frame(width: 280, height: 350)
            }
        }
    .padding(.vertical, 4)
    }
}

// MARK: - Calculation Method Picker Component
struct CalculationMethodPicker: View {
    @Binding var selectedMethod: Int
    let appLanguage: String
    @State private var isShowingPopover = false
    
    private let methods: [(id: Int, key: String)] = [
        (1, "method_karachi"),
        (2, "method_isna"),
        (3, "method_mwl"),
        (4, "method_umm_al_qura"),
        (5, "method_egyptian"),
        (7, "method_tehran"),
        (8, "method_gulf"),
        (9, "method_kuwait"),
        (10, "method_qatar"),
        (11, "method_singapore"),
        (12, "method_france"),
        (13, "method_turkey"),
        (14, "method_russia"),
        (15, "method_moonsighting"),
        (16, "method_dubai"),
        (17, "method_malaysia"),
        (18, "method_tunisia"),
        (19, "method_algeria"),
        (20, "method_indonesia"),
        (21, "method_morocco"),
        (22, "method_portugal"),
        (23, "method_jordan")
    ]
    
    private func getMethodName(for id: Int) -> String {
        if let method = methods.first(where: { $0.id == id }) {
            return Translations.string(method.key, language: appLanguage)
        }
        return "Unknown"
    }
    
    var body: some View {
        HStack {
            Text(getMethodName(for: selectedMethod))
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
            
            Button {
                isShowingPopover.toggle()
            } label: {
                Text(Translations.string("change", language: appLanguage))
                    .font(.system(size: 12))
            }
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                List {
                    ForEach(methods, id: \.id) { method in
                        Button {
                            selectedMethod = method.id
                            isShowingPopover = false
                        } label: {
                            HStack {
                                Text(Translations.string(method.key, language: appLanguage))
                                    .foregroundColor(.primary)
                                Spacer()
                                if method.id == selectedMethod {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.sidebar)
                .frame(width: 280, height: 350)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Language Radio Button Component
struct LanguageRadioButton: View {
    let title: String
    let tag: String
    @Binding var selection: String
    @State private var isPressed = false
    
    var isSelected: Bool {
        selection == tag
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                            .frame(width: 16, height: 16)
                    )
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isPressed ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = tag
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Time Format Radio Button Component
struct TimeFormatRadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 1)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                            .frame(width: 16, height: 16)
                    )
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
        .opacity(isPressed ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Number Format Radio Button Component
struct NumberFormatRadioButton: View {
    let title: String
    let example: String
    let tag: String
    @Binding var selection: String
    @State private var isPressed = false
    
    var isSelected: Bool {
        selection == tag
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 1)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color.clear)
                                .frame(width: 16, height: 16)
                        )
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                }
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            Text(example)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .opacity(isPressed ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = tag
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Prayer Notification Row Component
struct PrayerNotificationRow: View {
    let prayerName: String
    let icon: String
    @Binding var isEnabled: Bool
    @Binding var soundRawValue: String
    let appLanguage: String
    
    private var selectedSound: NotificationSound {
        NotificationSound(rawValue: soundRawValue) ?? .defaultSound
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isEnabled ? .accentColor : .secondary)
                .frame(width: 24)
            
            Text(prayerName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isEnabled ? .primary : .secondary)
                .frame(width: 60, alignment: Translations.isRTL(appLanguage) ? .trailing : .leading)
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.4))
                
                Picker("", selection: $soundRawValue) {
                    ForEach(NotificationSound.allCases) { sound in
                        Text(sound.displayName(language: appLanguage))
                            .tag(sound.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .controlSize(.small)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1.0 : 0.5)
                
                // Play sound preview button
                Button(action: {
                    playSystemSound(named: soundRawValue)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isEnabled ? .accentColor : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .help(Translations.string("play_sound", language: appLanguage))
            }
        }
    }
    
    private func playSystemSound(named soundName: String) {
        if soundName == "default" {
            NSSound.beep()
        } else if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        } else {
            // Fallback: try loading from system sounds directory
            let soundPath = "/System/Library/Sounds/\(soundName).aiff"
            if let sound = NSSound(contentsOfFile: soundPath, byReference: true) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }
}
