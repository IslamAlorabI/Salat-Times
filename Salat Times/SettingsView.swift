import SwiftUI
import CoreLocation
import ServiceManagement

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
                
                GroupBox(label: Label(Translations.string("prayer_notifications", language: appLanguage), systemImage: "bell.badge")) {
                    VStack(spacing: 12) {
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

enum Continent: String, CaseIterable, Identifiable {
    case africa = "Africa"
    case asia = "Asia"
    case australia = "Australia"
    case europe = "Europe"
    case middleEast = "Middle East"
    case northAmerica = "North America"
    case southAmerica = "South America"
    
    var id: String { self.rawValue }
    
    func getName(language: String) -> String {
        let names: [String: [String: String]] = [
            "Africa": ["ar": "أفريقيا", "en": "Africa", "ru": "Африка", "id": "Afrika", "tr": "Afrika", "ur": "افریقہ", "fa": "آفریقا", "de": "Afrika"],
            "Asia": ["ar": "آسيا", "en": "Asia", "ru": "Азия", "id": "Asia", "tr": "Asya", "ur": "ایشیا", "fa": "آسیا", "de": "Asien"],
            "Australia": ["ar": "أستراليا", "en": "Australia & Oceania", "ru": "Австралия", "id": "Australia", "tr": "Avustralya", "ur": "آسٹریلیا", "fa": "استرالیا", "de": "Australien"],
            "Europe": ["ar": "أوروبا", "en": "Europe", "ru": "Европа", "id": "Eropa", "tr": "Avrupa", "ur": "یورپ", "fa": "اروپا", "de": "Europa"],
            "Middle East": ["ar": "الشرق الأوسط", "en": "Middle East", "ru": "Ближний Восток", "id": "Timur Tengah", "tr": "Orta Doğu", "ur": "مشرق وسطیٰ", "fa": "خاورمیانه", "de": "Naher Osten"],
            "North America": ["ar": "أمريكا الشمالية", "en": "North America", "ru": "Северная Америка", "id": "Amerika Utara", "tr": "Kuzey Amerika", "ur": "شمالی امریکہ", "fa": "آمریکای شمالی", "de": "Nordamerika"],
            "South America": ["ar": "أمريكا الجنوبية", "en": "South America", "ru": "Южная Америка", "id": "Amerika Selatan", "tr": "Güney Amerika", "ur": "جنوبی امریکہ", "fa": "آمریکای جنوبی", "de": "Südamerika"]
        ]
        return names[self.rawValue]?[language] ?? names[self.rawValue]?["en"] ?? self.rawValue
    }
    
    var cities: [City] {
        City.allCases.filter { $0.continent == self }
    }
}

enum City: String, CaseIterable, Identifiable {
    // Africa
    case algiers = "Algiers"
    case cairo = "Cairo"
    case kafrElSheikh = "Kafr El-Sheikh"
    case alexandria = "Alexandria"
    case casablanca = "Casablanca"
    case capetown = "Capetown"
    case johannesburg = "Johannesburg"
    case lagos = "Lagos"
    case tunis = "Tunis"
    case rabat = "Rabat"
    case marrakech = "Marrakech"
    case fez = "Fez"
    
    // Asia
    case jakarta = "Jakarta"
    case karachi = "Karachi"
    case lahore = "Lahore"
    case islamabad = "Islamabad"
    case dhaka = "Dhaka"
    case mumbai = "Mumbai"
    case newDelhi = "New Delhi"
    case bangalore = "Bangalore"
    case chennai = "Chennai"
    case kolkata = "Kolkata"
    case singapore = "Singapore"
    case kualaLumpur = "Kuala Lumpur"
    case tokyo = "Tokyo"
    case seoul = "Seoul"
    case beijing = "Beijing"
    case shanghai = "Shanghai"
    case hongKong = "Hong Kong"
    case taipei = "Taipei"
    case tashkent = "Tashkent"
    case astana = "Astana"
    case kabul = "Kabul"
    
    // Australia & Oceania
    case sydney = "Sydney"
    case melbourne = "Melbourne"
    case perth = "Perth"
    case brisbane = "Brisbane"
    case auckland = "Auckland"
    case adelaide = "Adelaide"
    
    // Europe
    case london = "London"
    case paris = "Paris"
    case berlin = "Berlin"
    case moscow = "Moscow"
    case amsterdam = "Amsterdam"
    case brussels = "Brussels"
    case vienna = "Vienna"
    case zurich = "Zurich"
    case rome = "Rome"
    case milan = "Milan"
    case madrid = "Madrid"
    case barcelona = "Barcelona"
    case munich = "Munich"
    case frankfurt = "Frankfurt"
    case stockholm = "Stockholm"
    case oslo = "Oslo"
    case copenhagen = "Copenhagen"
    case helsinki = "Helsinki"
    case sarajevo = "Sarajevo"
    case istanbul = "Istanbul"
    case ankara = "Ankara"
    
    // Middle East
    case makkah = "Makkah"
    case madinah = "Madinah"
    case riyadh = "Riyadh"
    case jeddah = "Jeddah"
    case dubai = "Dubai"
    case abuDhabi = "Abu Dhabi"
    case doha = "Doha"
    case kuwait = "Kuwait City"
    case manama = "Manama"
    case muscat = "Muscat"
    case tehran = "Tehran"
    case baghdad = "Baghdad"
    case damascus = "Damascus"
    case amman = "Amman"
    case beirut = "Beirut"
    case jerusalem = "Jerusalem"
    case sanaa = "Sanaa"
    
    // North America
    case newYork = "New York"
    case losAngeles = "Los Angeles"
    case chicago = "Chicago"
    case houston = "Houston"
    case toronto = "Toronto"
    case vancouver = "Vancouver"
    case montreal = "Montreal"
    case washington = "Washington DC"
    case boston = "Boston"
    case detroit = "Detroit"
    case dallas = "Dallas"
    case miami = "Miami"
    case sanFrancisco = "San Francisco"
    case seattle = "Seattle"
    case mexicoCity = "Mexico City"
    
    // South America
    case saoPaulo = "Sao Paulo"
    case buenosAires = "Buenos Aires"
    case lima = "Lima"
    case bogota = "Bogota"
    case santiago = "Santiago"
    case caracas = "Caracas"
    
    var id: String { self.rawValue }
    
    var continent: Continent {
        switch self {
        case .algiers, .cairo, .kafrElSheikh, .alexandria, .casablanca, .capetown, .johannesburg, .lagos, .tunis, .rabat, .marrakech, .fez:
            return .africa
        case .jakarta, .karachi, .lahore, .islamabad, .dhaka, .mumbai, .newDelhi, .bangalore, .chennai, .kolkata, .singapore, .kualaLumpur, .tokyo, .seoul, .beijing, .shanghai, .hongKong, .taipei, .tashkent, .astana, .kabul:
            return .asia
        case .sydney, .melbourne, .perth, .brisbane, .auckland, .adelaide:
            return .australia
        case .london, .paris, .berlin, .moscow, .amsterdam, .brussels, .vienna, .zurich, .rome, .milan, .madrid, .barcelona, .munich, .frankfurt, .stockholm, .oslo, .copenhagen, .helsinki, .sarajevo, .istanbul, .ankara:
            return .europe
        case .makkah, .madinah, .riyadh, .jeddah, .dubai, .abuDhabi, .doha, .kuwait, .manama, .muscat, .tehran, .baghdad, .damascus, .amman, .beirut, .jerusalem, .sanaa:
            return .middleEast
        case .newYork, .losAngeles, .chicago, .houston, .toronto, .vancouver, .montreal, .washington, .boston, .detroit, .dallas, .miami, .sanFrancisco, .seattle, .mexicoCity:
            return .northAmerica
        case .saoPaulo, .buenosAires, .lima, .bogota, .santiago, .caracas:
            return .southAmerica
        }
    }
    
    func getName(language: String) -> String {
        let names: [String: [String: String]] = [
            // Africa
            "Algiers": ["ar": "الجزائر العاصمة", "en": "Algiers, Algeria", "ru": "Алжир", "id": "Aljir, Aljazair", "tr": "Cezayir", "ur": "الجزائر", "fa": "الجزایر", "de": "Algier"],
            "Cairo": ["ar": "القاهرة، مصر", "en": "Cairo, Egypt", "ru": "Каир, Египет", "id": "Kairo, Mesir", "tr": "Kahire, Mısır", "ur": "قاہرہ، مصر", "fa": "قاهره، مصر", "de": "Kairo, Ägypten"],
            "Casablanca": ["ar": "الدار البيضاء، المغرب", "en": "Casablanca, Morocco", "ru": "Касабланка", "id": "Casablanca, Maroko", "tr": "Kazablanka, Fas", "ur": "کاسابلانکا", "fa": "کازابلانکا", "de": "Casablanca, Marokko"],
            "Capetown": ["ar": "كيب تاون، جنوب أفريقيا", "en": "Cape Town, South Africa", "ru": "Кейптаун", "id": "Cape Town", "tr": "Cape Town", "ur": "کیپ ٹاؤن", "fa": "کیپ تاون", "de": "Kapstadt"],
            "Johannesburg": ["ar": "جوهانسبرغ، جنوب أفريقيا", "en": "Johannesburg, South Africa", "ru": "Йоханнесбург", "id": "Johannesburg", "tr": "Johannesburg", "ur": "جوہانسبرگ", "fa": "ژوهانسبورگ", "de": "Johannesburg"],
            "Lagos": ["ar": "لاغوس، نيجيريا", "en": "Lagos, Nigeria", "ru": "Лагос", "id": "Lagos, Nigeria", "tr": "Lagos, Nijerya", "ur": "لاگوس", "fa": "لاگوس", "de": "Lagos, Nigeria"],
            "Tunis": ["ar": "تونس العاصمة", "en": "Tunis, Tunisia", "ru": "Тунис", "id": "Tunis, Tunisia", "tr": "Tunus", "ur": "تیونس", "fa": "تونس", "de": "Tunis, Tunesien"],
            "Rabat": ["ar": "الرباط، المغرب", "en": "Rabat, Morocco", "ru": "Рабат", "id": "Rabat, Maroko", "tr": "Rabat, Fas", "ur": "رباط", "fa": "رباط", "de": "Rabat, Marokko"],
            "Marrakech": ["ar": "مراكش، المغرب", "en": "Marrakech, Morocco", "ru": "Марракеш", "id": "Marrakech", "tr": "Marakeş", "ur": "مراکش", "fa": "مراکش", "de": "Marrakesch"],
            "Fez": ["ar": "فاس، المغرب", "en": "Fez, Morocco", "ru": "Фес", "id": "Fez, Maroko", "tr": "Fes, Fas", "ur": "فیس", "fa": "فاس", "de": "Fès, Marokko"],
            
            // Asia
            "Jakarta": ["ar": "جاكرتا، إندونيسيا", "en": "Jakarta, Indonesia", "ru": "Джакарта", "id": "Jakarta, Indonesia", "tr": "Cakarta", "ur": "جکارتہ", "fa": "جاکارتا", "de": "Jakarta, Indonesien"],
            "Karachi": ["ar": "كراتشي، باكستان", "en": "Karachi, Pakistan", "ru": "Карачи", "id": "Karachi, Pakistan", "tr": "Karaçi", "ur": "کراچی، پاکستان", "fa": "کراچی", "de": "Karachi, Pakistan"],
            "Lahore": ["ar": "لاهور، باكستان", "en": "Lahore, Pakistan", "ru": "Лахор", "id": "Lahore, Pakistan", "tr": "Lahor", "ur": "لاہور، پاکستان", "fa": "لاهور", "de": "Lahore, Pakistan"],
            "Islamabad": ["ar": "إسلام آباد، باكستان", "en": "Islamabad, Pakistan", "ru": "Исламабад", "id": "Islamabad, Pakistan", "tr": "İslamabad", "ur": "اسلام آباد، پاکستان", "fa": "اسلام‌آباد", "de": "Islamabad, Pakistan"],
            "Dhaka": ["ar": "دكا، بنغلاديش", "en": "Dhaka, Bangladesh", "ru": "Дакка", "id": "Dhaka, Bangladesh", "tr": "Dakka", "ur": "ڈھاکہ", "fa": "داکا", "de": "Dhaka, Bangladesch"],
            "Mumbai": ["ar": "مومباي، الهند", "en": "Mumbai, India", "ru": "Мумбаи", "id": "Mumbai, India", "tr": "Mumbai", "ur": "ممبئی", "fa": "بمبئی", "de": "Mumbai, Indien"],
            "New Delhi": ["ar": "نيودلهي، الهند", "en": "New Delhi, India", "ru": "Нью-Дели", "id": "New Delhi, India", "tr": "Yeni Delhi", "ur": "نئی دہلی", "fa": "دهلی نو", "de": "Neu-Delhi, Indien"],
            "Bangalore": ["ar": "بنغالور، الهند", "en": "Bangalore, India", "ru": "Бангалор", "id": "Bangalore, India", "tr": "Bangalore", "ur": "بنگلور", "fa": "بنگلور", "de": "Bangalore, Indien"],
            "Chennai": ["ar": "تشيناي، الهند", "en": "Chennai, India", "ru": "Ченнаи", "id": "Chennai, India", "tr": "Chennai", "ur": "چنئی", "fa": "چنای", "de": "Chennai, Indien"],
            "Kolkata": ["ar": "كولكاتا، الهند", "en": "Kolkata, India", "ru": "Калькутта", "id": "Kolkata, India", "tr": "Kalküta", "ur": "کلکتہ", "fa": "کلکته", "de": "Kalkutta, Indien"],
            "Singapore": ["ar": "سنغافورة", "en": "Singapore", "ru": "Сингапур", "id": "Singapura", "tr": "Singapur", "ur": "سنگاپور", "fa": "سنگاپور", "de": "Singapur"],
            "Kuala Lumpur": ["ar": "كوالالمبور، ماليزيا", "en": "Kuala Lumpur, Malaysia", "ru": "Куала-Лумпур", "id": "Kuala Lumpur, Malaysia", "tr": "Kuala Lumpur", "ur": "کوالالمپور", "fa": "کوالالامپور", "de": "Kuala Lumpur, Malaysia"],
            "Tokyo": ["ar": "طوكيو، اليابان", "en": "Tokyo, Japan", "ru": "Токио", "id": "Tokyo, Jepang", "tr": "Tokyo", "ur": "ٹوکیو", "fa": "توکیو", "de": "Tokio, Japan"],
            "Seoul": ["ar": "سيول، كوريا الجنوبية", "en": "Seoul, South Korea", "ru": "Сеул", "id": "Seoul, Korea Selatan", "tr": "Seul", "ur": "سیول", "fa": "سئول", "de": "Seoul, Südkorea"],
            "Beijing": ["ar": "بكين، الصين", "en": "Beijing, China", "ru": "Пекин", "id": "Beijing, Tiongkok", "tr": "Pekin", "ur": "بیجنگ", "fa": "پکن", "de": "Peking, China"],
            "Shanghai": ["ar": "شنغهاي، الصين", "en": "Shanghai, China", "ru": "Шанхай", "id": "Shanghai, Tiongkok", "tr": "Şangay", "ur": "شنگھائی", "fa": "شانگهای", "de": "Shanghai, China"],
            "Hong Kong": ["ar": "هونغ كونغ", "en": "Hong Kong, China", "ru": "Гонконг", "id": "Hong Kong", "tr": "Hong Kong", "ur": "ہانگ کانگ", "fa": "هنگ‌کنگ", "de": "Hongkong, China"],
            "Taipei": ["ar": "تايبيه، تايوان", "en": "Taipei, Taiwan", "ru": "Тайбэй", "id": "Taipei, Taiwan", "tr": "Taipei", "ur": "تائی پے", "fa": "تایپه", "de": "Taipeh, Taiwan"],
            "Tashkent": ["ar": "طشقند، أوزبكستان", "en": "Tashkent, Uzbekistan", "ru": "Ташкент", "id": "Tashkent, Uzbekistan", "tr": "Taşkent", "ur": "تاشقند", "fa": "تاشکند", "de": "Taschkent, Usbekistan"],
            "Astana": ["ar": "أستانا، كازاخستان", "en": "Astana, Kazakhstan", "ru": "Астана", "id": "Astana, Kazakhstan", "tr": "Astana", "ur": "آستانہ", "fa": "آستانه", "de": "Astana, Kasachstan"],
            "Kabul": ["ar": "كابول، أفغانستان", "en": "Kabul, Afghanistan", "ru": "Кабул", "id": "Kabul, Afganistan", "tr": "Kabil", "ur": "کابل", "fa": "کابل", "de": "Kabul, Afghanistan"],
            
            // Australia
            "Sydney": ["ar": "سيدني، أستراليا", "en": "Sydney, Australia", "ru": "Сидней", "id": "Sydney, Australia", "tr": "Sidney", "ur": "سڈنی", "fa": "سیدنی", "de": "Sydney, Australien"],
            "Melbourne": ["ar": "ملبورن، أستراليا", "en": "Melbourne, Australia", "ru": "Мельбурн", "id": "Melbourne, Australia", "tr": "Melbourne", "ur": "میلبورن", "fa": "ملبورن", "de": "Melbourne, Australien"],
            "Perth": ["ar": "بيرث، أستراليا", "en": "Perth, Australia", "ru": "Перт", "id": "Perth, Australia", "tr": "Perth", "ur": "پرتھ", "fa": "پرث", "de": "Perth, Australien"],
            "Brisbane": ["ar": "بريزبن، أستراليا", "en": "Brisbane, Australia", "ru": "Брисбен", "id": "Brisbane, Australia", "tr": "Brisbane", "ur": "برسبین", "fa": "بریزبن", "de": "Brisbane, Australien"],
            "Auckland": ["ar": "أوكلاند، نيوزيلندا", "en": "Auckland, New Zealand", "ru": "Окленд", "id": "Auckland, Selandia Baru", "tr": "Auckland", "ur": "آکلینڈ", "fa": "اوکلند", "de": "Auckland, Neuseeland"],
            "Adelaide": ["ar": "أديلايد، أستراليا", "en": "Adelaide, Australia", "ru": "Аделаида", "id": "Adelaide, Australia", "tr": "Adelaide", "ur": "ایڈیلیڈ", "fa": "آدلاید", "de": "Adelaide, Australien"],
            
            // Europe
            "London": ["ar": "لندن، بريطانيا", "en": "London, UK", "ru": "Лондон", "id": "London, Inggris", "tr": "Londra", "ur": "لندن", "fa": "لندن", "de": "London, UK"],
            "Paris": ["ar": "باريس، فرنسا", "en": "Paris, France", "ru": "Париж", "id": "Paris, Prancis", "tr": "Paris", "ur": "پیرس", "fa": "پاریس", "de": "Paris, Frankreich"],
            "Berlin": ["ar": "برلين، ألمانيا", "en": "Berlin, Germany", "ru": "Берлин", "id": "Berlin, Jerman", "tr": "Berlin", "ur": "برلن", "fa": "برلین", "de": "Berlin, Deutschland"],
            "Moscow": ["ar": "موسكو، روسيا", "en": "Moscow, Russia", "ru": "Москва, Россия", "id": "Moskow, Rusia", "tr": "Moskova", "ur": "ماسکو", "fa": "مسکو", "de": "Moskau, Russland"],
            "Amsterdam": ["ar": "أمستردام، هولندا", "en": "Amsterdam, Netherlands", "ru": "Амстердам", "id": "Amsterdam, Belanda", "tr": "Amsterdam", "ur": "ایمسٹرڈیم", "fa": "آمستردام", "de": "Amsterdam, Niederlande"],
            "Brussels": ["ar": "بروكسل، بلجيكا", "en": "Brussels, Belgium", "ru": "Брюссель", "id": "Brussels, Belgia", "tr": "Brüksel", "ur": "برسلز", "fa": "بروکسل", "de": "Brüssel, Belgien"],
            "Vienna": ["ar": "فيينا، النمسا", "en": "Vienna, Austria", "ru": "Вена", "id": "Wina, Austria", "tr": "Viyana", "ur": "ویانا", "fa": "وین", "de": "Wien, Österreich"],
            "Zurich": ["ar": "زيوريخ، سويسرا", "en": "Zurich, Switzerland", "ru": "Цюрих", "id": "Zurich, Swiss", "tr": "Zürih", "ur": "زیورخ", "fa": "زوریخ", "de": "Zürich, Schweiz"],
            "Rome": ["ar": "روما، إيطاليا", "en": "Rome, Italy", "ru": "Рим", "id": "Roma, Italia", "tr": "Roma", "ur": "روم", "fa": "رم", "de": "Rom, Italien"],
            "Milan": ["ar": "ميلانو، إيطاليا", "en": "Milan, Italy", "ru": "Милан", "id": "Milan, Italia", "tr": "Milano", "ur": "میلان", "fa": "میلان", "de": "Mailand, Italien"],
            "Madrid": ["ar": "مدريد، إسبانيا", "en": "Madrid, Spain", "ru": "Мадрид", "id": "Madrid, Spanyol", "tr": "Madrid", "ur": "میڈرڈ", "fa": "مادرید", "de": "Madrid, Spanien"],
            "Barcelona": ["ar": "برشلونة، إسبانيا", "en": "Barcelona, Spain", "ru": "Барселона", "id": "Barcelona, Spanyol", "tr": "Barselona", "ur": "بارسلونا", "fa": "بارسلون", "de": "Barcelona, Spanien"],
            "Munich": ["ar": "ميونيخ، ألمانيا", "en": "Munich, Germany", "ru": "Мюнхен", "id": "Munich, Jerman", "tr": "Münih", "ur": "میونخ", "fa": "مونیخ", "de": "München, Deutschland"],
            "Frankfurt": ["ar": "فرانكفورت، ألمانيا", "en": "Frankfurt, Germany", "ru": "Франкфурт", "id": "Frankfurt, Jerman", "tr": "Frankfurt", "ur": "فرینکفرٹ", "fa": "فرانکفورت", "de": "Frankfurt, Deutschland"],
            "Stockholm": ["ar": "ستوكهولم، السويد", "en": "Stockholm, Sweden", "ru": "Стокгольм", "id": "Stockholm, Swedia", "tr": "Stockholm", "ur": "سٹاک ہوم", "fa": "استکهلم", "de": "Stockholm, Schweden"],
            "Oslo": ["ar": "أوسلو، النرويج", "en": "Oslo, Norway", "ru": "Осло", "id": "Oslo, Norwegia", "tr": "Oslo", "ur": "اوسلو", "fa": "اسلو", "de": "Oslo, Norwegen"],
            "Copenhagen": ["ar": "كوبنهاغن، الدنمارك", "en": "Copenhagen, Denmark", "ru": "Копенгаген", "id": "Kopenhagen, Denmark", "tr": "Kopenhag", "ur": "کوپن ہیگن", "fa": "کپنهاگ", "de": "Kopenhagen, Dänemark"],
            "Helsinki": ["ar": "هلسنكي، فنلندا", "en": "Helsinki, Finland", "ru": "Хельсинки", "id": "Helsinki, Finlandia", "tr": "Helsinki", "ur": "ہیلسنکی", "fa": "هلسینکی", "de": "Helsinki, Finnland"],
            "Sarajevo": ["ar": "سراييفو، البوسنة", "en": "Sarajevo, Bosnia", "ru": "Сараево", "id": "Sarajevo, Bosnia", "tr": "Saraybosna", "ur": "سراجیوو", "fa": "سارایوو", "de": "Sarajevo, Bosnien"],
            "Istanbul": ["ar": "إسطنبول، تركيا", "en": "Istanbul, Turkey", "ru": "Стамбул", "id": "Istanbul, Turki", "tr": "İstanbul, Türkiye", "ur": "استنبول", "fa": "استانبول", "de": "Istanbul, Türkei"],
            "Ankara": ["ar": "أنقرة، تركيا", "en": "Ankara, Turkey", "ru": "Анкара", "id": "Ankara, Turki", "tr": "Ankara, Türkiye", "ur": "انقرہ", "fa": "آنکارا", "de": "Ankara, Türkei"],
            
            // Middle East
            "Makkah": ["ar": "مكة المكرمة", "en": "Makkah, Saudi Arabia", "ru": "Мекка", "id": "Mekkah, Arab Saudi", "tr": "Mekke", "ur": "مکہ مکرمہ", "fa": "مکه", "de": "Mekka, Saudi-Arabien"],
            "Madinah": ["ar": "المدينة المنورة", "en": "Madinah, Saudi Arabia", "ru": "Медина", "id": "Madinah, Arab Saudi", "tr": "Medine", "ur": "مدینہ منورہ", "fa": "مدینه", "de": "Medina, Saudi-Arabien"],
            "Riyadh": ["ar": "الرياض، السعودية", "en": "Riyadh, Saudi Arabia", "ru": "Эр-Рияд", "id": "Riyadh, Arab Saudi", "tr": "Riyad", "ur": "ریاض", "fa": "ریاض", "de": "Riad, Saudi-Arabien"],
            "Jeddah": ["ar": "جدة، السعودية", "en": "Jeddah, Saudi Arabia", "ru": "Джидда", "id": "Jeddah, Arab Saudi", "tr": "Cidde", "ur": "جدہ", "fa": "جده", "de": "Dschidda, Saudi-Arabien"],
            "Dubai": ["ar": "دبي، الإمارات", "en": "Dubai, UAE", "ru": "Дубай", "id": "Dubai, UEA", "tr": "Dubai", "ur": "دبئی", "fa": "دبی", "de": "Dubai, VAE"],
            "Abu Dhabi": ["ar": "أبو ظبي، الإمارات", "en": "Abu Dhabi, UAE", "ru": "Абу-Даби", "id": "Abu Dhabi, UEA", "tr": "Abu Dabi", "ur": "ابوظہبی", "fa": "ابوظبی", "de": "Abu Dhabi, VAE"],
            "Doha": ["ar": "الدوحة، قطر", "en": "Doha, Qatar", "ru": "Доха", "id": "Doha, Qatar", "tr": "Doha", "ur": "دوحہ", "fa": "دوحه", "de": "Doha, Katar"],
            "Kuwait City": ["ar": "مدينة الكويت", "en": "Kuwait City, Kuwait", "ru": "Эль-Кувейт", "id": "Kuwait City, Kuwait", "tr": "Kuveyt", "ur": "کویت سٹی", "fa": "شهر کویت", "de": "Kuwait-Stadt, Kuwait"],
            "Manama": ["ar": "المنامة، البحرين", "en": "Manama, Bahrain", "ru": "Манама", "id": "Manama, Bahrain", "tr": "Manama", "ur": "منامہ", "fa": "منامه", "de": "Manama, Bahrain"],
            "Muscat": ["ar": "مسقط، عمان", "en": "Muscat, Oman", "ru": "Маскат", "id": "Muscat, Oman", "tr": "Maskat", "ur": "مسقط", "fa": "مسقط", "de": "Maskat, Oman"],
            "Tehran": ["ar": "طهران، إيران", "en": "Tehran, Iran", "ru": "Тегеран", "id": "Tehran, Iran", "tr": "Tahran", "ur": "تہران", "fa": "تهران، ایران", "de": "Teheran, Iran"],
            "Baghdad": ["ar": "بغداد، العراق", "en": "Baghdad, Iraq", "ru": "Багдад", "id": "Baghdad, Irak", "tr": "Bağdat", "ur": "بغداد", "fa": "بغداد", "de": "Bagdad, Irak"],
            "Damascus": ["ar": "دمشق، سوريا", "en": "Damascus, Syria", "ru": "Дамаск", "id": "Damaskus, Suriah", "tr": "Şam", "ur": "دمشق", "fa": "دمشق", "de": "Damaskus, Syrien"],
            "Amman": ["ar": "عمان، الأردن", "en": "Amman, Jordan", "ru": "Амман", "id": "Amman, Yordania", "tr": "Amman", "ur": "عمان", "fa": "امان", "de": "Amman, Jordanien"],
            "Beirut": ["ar": "بيروت، لبنان", "en": "Beirut, Lebanon", "ru": "Бейрут", "id": "Beirut, Lebanon", "tr": "Beyrut", "ur": "بیروت", "fa": "بیروت", "de": "Beirut, Libanon"],
            "Jerusalem": ["ar": "القدس، فلسطين", "en": "Jerusalem, Palestine", "ru": "Иерусалим", "id": "Yerusalem, Palestina", "tr": "Kudüs", "ur": "القدس", "fa": "قدس", "de": "Jerusalem, Palästina"],
            "Sanaa": ["ar": "صنعاء، اليمن", "en": "Sanaa, Yemen", "ru": "Сана", "id": "Sana'a, Yaman", "tr": "Sana", "ur": "صنعاء", "fa": "صنعا", "de": "Sanaa, Jemen"],
            "Kafr El-Sheikh": ["ar": "كفر الشيخ، مصر", "en": "Kafr El-Sheikh, Egypt", "ru": "Кафр-эш-Шейх", "id": "Kafr El-Sheikh, Mesir", "tr": "Kafr El-Sheikh", "ur": "کفر الشیخ", "fa": "کفر الشیخ", "de": "Kafr El-Sheikh, Ägypten"],
            "Alexandria": ["ar": "الإسكندرية، مصر", "en": "Alexandria, Egypt", "ru": "Александрия", "id": "Alexandria, Mesir", "tr": "İskenderiye", "ur": "اسکندریہ", "fa": "اسکندریه", "de": "Alexandria, Ägypten"],
            
            // North America
            "New York": ["ar": "نيويورك، أمريكا", "en": "New York, USA", "ru": "Нью-Йорк", "id": "New York, AS", "tr": "New York", "ur": "نیویارک", "fa": "نیویورک", "de": "New York, USA"],
            "Los Angeles": ["ar": "لوس أنجلوس، أمريكا", "en": "Los Angeles, USA", "ru": "Лос-Анджелес", "id": "Los Angeles, AS", "tr": "Los Angeles", "ur": "لاس اینجلس", "fa": "لس‌آنجلس", "de": "Los Angeles, USA"],
            "Chicago": ["ar": "شيكاغو، أمريكا", "en": "Chicago, USA", "ru": "Чикаго", "id": "Chicago, AS", "tr": "Chicago", "ur": "شکاگو", "fa": "شیکاگو", "de": "Chicago, USA"],
            "Houston": ["ar": "هيوستن، أمريكا", "en": "Houston, USA", "ru": "Хьюстон", "id": "Houston, AS", "tr": "Houston", "ur": "ہوسٹن", "fa": "هیوستون", "de": "Houston, USA"],
            "Toronto": ["ar": "تورنتو، كندا", "en": "Toronto, Canada", "ru": "Торонто", "id": "Toronto, Kanada", "tr": "Toronto", "ur": "ٹورنٹو", "fa": "تورنتو", "de": "Toronto, Kanada"],
            "Vancouver": ["ar": "فانكوفر، كندا", "en": "Vancouver, Canada", "ru": "Ванкувер", "id": "Vancouver, Kanada", "tr": "Vancouver", "ur": "وینکوور", "fa": "ونکوور", "de": "Vancouver, Kanada"],
            "Montreal": ["ar": "مونتريال، كندا", "en": "Montreal, Canada", "ru": "Монреаль", "id": "Montreal, Kanada", "tr": "Montreal", "ur": "مانٹریال", "fa": "مونترال", "de": "Montreal, Kanada"],
            "Washington DC": ["ar": "واشنطن، أمريكا", "en": "Washington DC, USA", "ru": "Вашингтон", "id": "Washington DC, AS", "tr": "Washington", "ur": "واشنگٹن", "fa": "واشینگتن", "de": "Washington D.C., USA"],
            "Boston": ["ar": "بوسطن، أمريكا", "en": "Boston, USA", "ru": "Бостон", "id": "Boston, AS", "tr": "Boston", "ur": "بوسٹن", "fa": "بوستون", "de": "Boston, USA"],
            "Detroit": ["ar": "ديترويت، أمريكا", "en": "Detroit, USA", "ru": "Детройт", "id": "Detroit, AS", "tr": "Detroit", "ur": "ڈیٹرائٹ", "fa": "دیترویت", "de": "Detroit, USA"],
            "Dallas": ["ar": "دالاس، أمريكا", "en": "Dallas, USA", "ru": "Даллас", "id": "Dallas, AS", "tr": "Dallas", "ur": "ڈیلاس", "fa": "دالاس", "de": "Dallas, USA"],
            "Miami": ["ar": "ميامي، أمريكا", "en": "Miami, USA", "ru": "Майами", "id": "Miami, AS", "tr": "Miami", "ur": "میامی", "fa": "میامی", "de": "Miami, USA"],
            "San Francisco": ["ar": "سان فرانسيسكو، أمريكا", "en": "San Francisco, USA", "ru": "Сан-Франциско", "id": "San Francisco, AS", "tr": "San Francisco", "ur": "سان فرانسسکو", "fa": "سان‌فرانسیسکو", "de": "San Francisco, USA"],
            "Seattle": ["ar": "سياتل، أمريكا", "en": "Seattle, USA", "ru": "Сиэтл", "id": "Seattle, AS", "tr": "Seattle", "ur": "سیٹل", "fa": "سیاتل", "de": "Seattle, USA"],
            
            // South America
            "Sao Paulo": ["ar": "ساو باولو، البرازيل", "en": "São Paulo, Brazil", "ru": "Сан-Паулу", "id": "Sao Paulo, Brasil", "tr": "São Paulo", "ur": "ساؤ پالو", "fa": "سائوپائولو", "de": "São Paulo, Brasilien"],
            "Buenos Aires": ["ar": "بوينس آيرس، الأرجنتين", "en": "Buenos Aires, Argentina", "ru": "Буэнос-Айрес", "id": "Buenos Aires, Argentina", "tr": "Buenos Aires", "ur": "بیونس آئرس", "fa": "بوینس‌آیرس", "de": "Buenos Aires, Argentinien"],
            "Lima": ["ar": "ليما، بيرو", "en": "Lima, Peru", "ru": "Лима", "id": "Lima, Peru", "tr": "Lima", "ur": "لیما", "fa": "لیما", "de": "Lima, Peru"],
            "Bogota": ["ar": "بوغوتا، كولومبيا", "en": "Bogotá, Colombia", "ru": "Богота", "id": "Bogota, Kolombia", "tr": "Bogota", "ur": "بوگوٹا", "fa": "بوگوتا", "de": "Bogotá, Kolumbien"],
            "Santiago": ["ar": "سانتياغو، تشيلي", "en": "Santiago, Chile", "ru": "Сантьяго", "id": "Santiago, Chili", "tr": "Santiago", "ur": "سینٹیاگو", "fa": "سانتیاگو", "de": "Santiago, Chile"],
            "Mexico City": ["ar": "مكسيكو سيتي، المكسيك", "en": "Mexico City, Mexico", "ru": "Мехико", "id": "Mexico City, Meksiko", "tr": "Mexico City", "ur": "میکسیکو سٹی", "fa": "مکزیکوسیتی", "de": "Mexiko-Stadt, Mexiko"],
            "Caracas": ["ar": "كاراكاس، فنزويلا", "en": "Caracas, Venezuela", "ru": "Каракас", "id": "Caracas, Venezuela", "tr": "Karakas", "ur": "کاراکاس", "fa": "کاراکاس", "de": "Caracas, Venezuela"]
        ]
        return names[self.rawValue]?[language] ?? names[self.rawValue]?["en"] ?? self.rawValue
    }
    
    var coordinates: CLLocationCoordinate2D {
        switch self {
        // Africa
        case .algiers: return CLLocationCoordinate2D(latitude: 36.7528, longitude: 3.0420)
        case .cairo: return CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)
        case .casablanca: return CLLocationCoordinate2D(latitude: 33.5731, longitude: -7.5898)
        case .capetown: return CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)
        case .johannesburg: return CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)
        case .lagos: return CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)
        case .tunis: return CLLocationCoordinate2D(latitude: 36.8065, longitude: 10.1815)
        case .rabat: return CLLocationCoordinate2D(latitude: 34.0209, longitude: -6.8416)
        case .marrakech: return CLLocationCoordinate2D(latitude: 31.6295, longitude: -7.9811)
        case .fez: return CLLocationCoordinate2D(latitude: 34.0181, longitude: -5.0078)
        
        // Asia
        case .jakarta: return CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)
        case .karachi: return CLLocationCoordinate2D(latitude: 24.8607, longitude: 67.0011)
        case .lahore: return CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3587)
        case .islamabad: return CLLocationCoordinate2D(latitude: 33.6844, longitude: 73.0479)
        case .dhaka: return CLLocationCoordinate2D(latitude: 23.8103, longitude: 90.4125)
        case .mumbai: return CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
        case .newDelhi: return CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090)
        case .bangalore: return CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
        case .chennai: return CLLocationCoordinate2D(latitude: 13.0827, longitude: 80.2707)
        case .kolkata: return CLLocationCoordinate2D(latitude: 22.5726, longitude: 88.3639)
        case .singapore: return CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)
        case .kualaLumpur: return CLLocationCoordinate2D(latitude: 3.1390, longitude: 101.6869)
        case .tokyo: return CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        case .seoul: return CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        case .beijing: return CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        case .shanghai: return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        case .hongKong: return CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)
        case .taipei: return CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)
        case .tashkent: return CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401)
        case .astana: return CLLocationCoordinate2D(latitude: 51.1694, longitude: 71.4491)
        case .kabul: return CLLocationCoordinate2D(latitude: 34.5553, longitude: 69.2075)
        
        // Australia
        case .sydney: return CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
        case .melbourne: return CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
        case .perth: return CLLocationCoordinate2D(latitude: -31.9505, longitude: 115.8605)
        case .brisbane: return CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251)
        case .auckland: return CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633)
        case .adelaide: return CLLocationCoordinate2D(latitude: -34.9285, longitude: 138.6007)
        
        // Europe
        case .london: return CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        case .paris: return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        case .berlin: return CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)
        case .moscow: return CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        case .amsterdam: return CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        case .brussels: return CLLocationCoordinate2D(latitude: 50.8503, longitude: 4.3517)
        case .vienna: return CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)
        case .zurich: return CLLocationCoordinate2D(latitude: 47.3769, longitude: 8.5417)
        case .rome: return CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)
        case .milan: return CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        case .madrid: return CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
        case .barcelona: return CLLocationCoordinate2D(latitude: 41.3851, longitude: 2.1734)
        case .munich: return CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820)
        case .frankfurt: return CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)
        case .stockholm: return CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)
        case .oslo: return CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        case .copenhagen: return CLLocationCoordinate2D(latitude: 55.6761, longitude: 12.5683)
        case .helsinki: return CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384)
        case .sarajevo: return CLLocationCoordinate2D(latitude: 43.8563, longitude: 18.4131)
        case .istanbul: return CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
        case .ankara: return CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
        
        // Middle East
        case .makkah: return CLLocationCoordinate2D(latitude: 21.3891, longitude: 39.8579)
        case .madinah: return CLLocationCoordinate2D(latitude: 24.5247, longitude: 39.5692)
        case .riyadh: return CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        case .jeddah: return CLLocationCoordinate2D(latitude: 21.4858, longitude: 39.1925)
        case .dubai: return CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)
        case .abuDhabi: return CLLocationCoordinate2D(latitude: 24.4539, longitude: 54.3773)
        case .doha: return CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310)
        case .kuwait: return CLLocationCoordinate2D(latitude: 29.3759, longitude: 47.9774)
        case .manama: return CLLocationCoordinate2D(latitude: 26.2285, longitude: 50.5860)
        case .muscat: return CLLocationCoordinate2D(latitude: 23.5880, longitude: 58.3829)
        case .tehran: return CLLocationCoordinate2D(latitude: 35.6892, longitude: 51.3890)
        case .baghdad: return CLLocationCoordinate2D(latitude: 33.3152, longitude: 44.3661)
        case .damascus: return CLLocationCoordinate2D(latitude: 33.5138, longitude: 36.2765)
        case .amman: return CLLocationCoordinate2D(latitude: 31.9454, longitude: 35.9284)
        case .beirut: return CLLocationCoordinate2D(latitude: 33.8938, longitude: 35.5018)
        case .jerusalem: return CLLocationCoordinate2D(latitude: 31.7683, longitude: 35.2137)
        case .sanaa: return CLLocationCoordinate2D(latitude: 15.3694, longitude: 44.1910)
        case .kafrElSheikh: return CLLocationCoordinate2D(latitude: 31.1107, longitude: 30.9388)
        case .alexandria: return CLLocationCoordinate2D(latitude: 31.2001, longitude: 29.9187)
        
        // North America
        case .newYork: return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        case .losAngeles: return CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        case .chicago: return CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)
        case .houston: return CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698)
        case .toronto: return CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
        case .vancouver: return CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)
        case .montreal: return CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673)
        case .washington: return CLLocationCoordinate2D(latitude: 38.9072, longitude: -77.0369)
        case .boston: return CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)
        case .detroit: return CLLocationCoordinate2D(latitude: 42.3314, longitude: -83.0458)
        case .dallas: return CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970)
        case .miami: return CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)
        case .sanFrancisco: return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        case .seattle: return CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        
        // South America
        case .saoPaulo: return CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333)
        case .buenosAires: return CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816)
        case .lima: return CLLocationCoordinate2D(latitude: -12.0464, longitude: -77.0428)
        case .bogota: return CLLocationCoordinate2D(latitude: 4.7110, longitude: -74.0721)
        case .santiago: return CLLocationCoordinate2D(latitude: -33.4489, longitude: -70.6693)
        case .mexicoCity: return CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)
        case .caracas: return CLLocationCoordinate2D(latitude: 10.4806, longitude: -66.9036)
        }
    }
    
    var recommendedMethod: Int {
        switch self {
        // Egypt - Egyptian General Authority (5)
        case .cairo, .kafrElSheikh, .alexandria:
            return 5
        // Algeria - Algeria (19)
        case .algiers:
            return 19
        // Morocco - Morocco (21)
        case .casablanca, .rabat, .marrakech, .fez:
            return 21
        // Tunisia - Tunisia (18)
        case .tunis:
            return 18
        // South Africa & Nigeria - Muslim World League (3)
        case .capetown, .johannesburg, .lagos:
            return 3
        // Pakistan - University of Karachi (1)
        case .karachi, .lahore, .islamabad:
            return 1
        // Indonesia - Indonesia KEMENAG (20)
        case .jakarta:
            return 20
        // Malaysia - Malaysia JAKIM (17)
        case .kualaLumpur:
            return 17
        // Singapore - Singapore MUIS (11)
        case .singapore:
            return 11
        // India/Bangladesh - University of Karachi (1)
        case .dhaka, .mumbai, .newDelhi, .bangalore, .chennai, .kolkata:
            return 1
        // Turkey - Turkey Diyanet (13)
        case .istanbul, .ankara:
            return 13
        // Iran - University of Tehran (7)
        case .tehran:
            return 7
        // Saudi Arabia - Umm Al-Qura (4)
        case .makkah, .madinah, .riyadh, .jeddah:
            return 4
        // UAE - Dubai (16)
        case .dubai, .abuDhabi:
            return 16
        // Qatar - Qatar (10)
        case .doha:
            return 10
        // Kuwait - Kuwait (9)
        case .kuwait:
            return 9
        // Gulf Region - Gulf (8)
        case .manama, .muscat:
            return 8
        // Iraq, Syria, Lebanon, Jordan, Palestine, Yemen - Umm Al-Qura (4)
        case .baghdad, .damascus, .beirut, .amman, .jerusalem, .sanaa:
            return 4
        // Russia - Russia (14)
        case .moscow:
            return 14
        // France - France UOIF (12)
        case .paris:
            return 12
        // Europe (general) - Muslim World League (3)
        case .london, .berlin, .amsterdam, .brussels, .vienna, .zurich, .rome, .milan, .madrid, .barcelona, .munich, .frankfurt, .stockholm, .oslo, .copenhagen, .helsinki, .sarajevo:
            return 3
        // North America - ISNA (2)
        case .newYork, .losAngeles, .chicago, .houston, .toronto, .vancouver, .montreal, .washington, .boston, .detroit, .dallas, .miami, .sanFrancisco, .seattle, .mexicoCity:
            return 2
        // South America - Muslim World League (3)
        case .saoPaulo, .buenosAires, .lima, .bogota, .santiago, .caracas:
            return 3
        // Asia (general) - Muslim World League (3)
        case .tokyo, .seoul, .beijing, .shanghai, .hongKong, .taipei, .tashkent, .astana, .kabul:
            return 3
        // Australia - Muslim World League (3)
        case .sydney, .melbourne, .perth, .brisbane, .auckland, .adelaide:
            return 3
        }
    }
}
