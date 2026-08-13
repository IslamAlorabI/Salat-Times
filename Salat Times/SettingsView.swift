import SwiftUI
import os
import CoreLocation
import ServiceManagement
import UserNotifications

// The settings window.
//
// A fixed sidebar, not a `TabView`. The tab strip compressed and then clipped its own
// items as the window narrowed, so a pane could become unreachable at a width the user
// was allowed to drag to. A sidebar has a floor: it is 190pt and stays 190pt.
//
// Panes never call back into `PrayerManager` to make a setting take effect — the
// manager's debounced `UserDefaults` diff does that (`observeSettingsChanges`). The only
// `manager` calls in this whole window are real actions: refresh now, and re-reading the
// notification authorization.

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("listMaterial") private var listMaterial = PopoverMaterial.subtle.rawValue
    @State private var selection: SettingsSection = .general

    private var isRTL: Bool { Translations.isRTL(appLanguage) }
    private var material: PopoverMaterial { PopoverMaterial.stored(listMaterial) }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().ignoresSafeArea()
            detail
        }
        .frame(minWidth: 680, minHeight: 580)
        // One background for the whole window, behind everything. Painting the sidebar
        // and the detail pane separately left the gap between them unpainted, and because
        // the window was clear that gap rendered as a black band.
        .background(TranslucentBackground(level: material))
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Clears the traffic lights, which float over the content because the window
            // uses `.hiddenTitleBar`.
            Color.clear.frame(height: 26)

            ForEach(SettingsSection.allCases) { section in
                SettingsSidebarItem(section: section,
                                    isSelected: selection == section,
                                    appLanguage: appLanguage) {
                    selection = section
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .frame(width: 190, alignment: .top)
        .frame(maxHeight: .infinity)
        // A tint over the shared background rather than a material of its own, so the
        // sidebar reads as a sidebar at every translucency level without ever becoming a
        // second, differently-blurred surface.
        //
        // `.ignoresSafeArea()` is what makes it reach the very top. The window uses
        // `.hiddenTitleBar`, but the *content* is still inset below where the title bar
        // would be, so the tint stopped short and the window background showed through as
        // a pale strip above the sidebar.
        .background(Color.primary.opacity(0.05).ignoresSafeArea())
    }

    private var detail: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(Translations.string(selection.titleKey, language: appLanguage))
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                switch selection {
                case .general:       GeneralSettingsPane()
                case .prayerTimes:   PrayerTimesSettingsPane()
                case .appearance:    AppearanceSettingsPane()
                case .notifications: NotificationSettingsPane()
                case .about:         AboutView()
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - General

struct GeneralSettingsPane: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    var body: some View {
        SettingsCard(title: Translations.string("startup", language: appLanguage)) {
            SettingsRow(title: Translations.string("launch_at_login", language: appLanguage)) {
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            Log.data.error("Could not update launch at login: \(error.localizedDescription, privacy: .public)")
                            launchAtLogin = !newValue
                        }
                    }
            }

            SettingsDivider()

            SettingsRow(title: Translations.string("refresh_data", language: appLanguage),
                        subtitle: Translations.string("refresh_data_hint", language: appLanguage)) {
                Button {
                    manager.loadSavedCity()
                } label: {
                    Label(Translations.string("refresh", language: appLanguage),
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12))
                }
            }
        }

        SettingsCard(title: Translations.string("languages", language: appLanguage)) {
            SettingsStackedRow(title: Translations.string("interface_language", language: appLanguage)) {
                let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    LanguageRadioButton(title: Translations.string("language_ar", language: "ar"), tag: "ar", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_en", language: "en"), tag: "en", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_ru", language: "ru"), tag: "ru", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_id", language: "id"), tag: "id", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_tr", language: "tr"), tag: "tr", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_ur", language: "ur"), tag: "ur", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_fa", language: "fa"), tag: "fa", selection: $appLanguage)
                    LanguageRadioButton(title: Translations.string("language_de", language: "de"), tag: "de", selection: $appLanguage)
                }
            }
        }
    }
}

// MARK: - Prayer times

struct PrayerTimesSettingsPane: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    @AppStorage("calculationMethod") private var method = 5

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    var body: some View {
        SettingsCard(title: Translations.string("location", language: appLanguage)) {
            SettingsStackedRow(title: Translations.string("location", language: appLanguage)) {
                CitySearchPicker(selectedCityRaw: $selectedCityRaw, appLanguage: appLanguage)
            }
            SettingsDivider()
            SettingsStackedRow(title: Translations.string("calculation_method", language: appLanguage)) {
                CalculationMethodPicker(selectedMethod: $method, appLanguage: appLanguage)
            }
        }
        // The only `.onChange` left in the settings window, and it is here because it
        // *writes another preference* rather than reacting to this one: choosing a city
        // moves the calculation method to the one that city's authority uses.
        .onChange(of: selectedCityRaw) { newValue in
            if let city = City(rawValue: newValue) {
                method = city.recommendedMethod
            }
        }

        CalculationOptionsSection()
        PrayerTuningSection()
        FixedOffsetsSection()
    }
}

// MARK: - Appearance

struct AppearanceSettingsPane: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    @AppStorage("numberFormat") private var numberFormat = "western"
    @AppStorage("listMaterial") private var listMaterial = PopoverMaterial.subtle.rawValue
    @AppStorage("showNightTimes") private var showNightTimes = true

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    var body: some View {
        SettingsCard(title: Translations.string("time_format", language: appLanguage)) {
            SettingsStackedRow(title: Translations.string("time_format", language: appLanguage)) {
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
            }

            SettingsDivider()

            SettingsStackedRow(title: Translations.string("number_format", language: appLanguage)) {
                HStack(spacing: 0) {
                    NumberFormatRadioButton(title: Translations.string("numbers_western", language: appLanguage),
                                            example: "123", tag: "western", selection: $numberFormat)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                    NumberFormatRadioButton(title: Translations.string("numbers_arabic", language: appLanguage),
                                            example: "١٢٣", tag: "arabic", selection: $numberFormat)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                    NumberFormatRadioButton(title: Translations.string("numbers_persian", language: appLanguage),
                                            example: "۱۲۳", tag: "persian", selection: $numberFormat)
                }
            }
        }

        SettingsCard(title: Translations.string("menu_bar_panel", language: appLanguage),
                     footnote: Translations.string("translucency_hint", language: appLanguage)) {
            SettingsRow(title: Translations.string("translucency", language: appLanguage)) {
                Picker("", selection: $listMaterial) {
                    ForEach(PopoverMaterial.allCases) { level in
                        Text(Translations.string(level.titleKey, language: appLanguage)).tag(level.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            SettingsDivider()

            SettingsRow(title: Translations.string("show_night_times", language: appLanguage),
                        subtitle: Translations.string("show_night_times_hint", language: appLanguage)) {
                Toggle("", isOn: $showNightTimes)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Notifications

struct NotificationSettingsPane: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("reminderInterval") private var reminderInterval = 0
    @AppStorage("warningInterval") private var warningInterval = 0

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

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    var body: some View {
        // Every toggle below is inert if macOS has notifications denied, and nothing else
        // in the app would ever say so.
        if manager.notificationAuthorization == .denied {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
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
                Spacer(minLength: 0)
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            )
        }

        SettingsCard(title: Translations.string("prayer_notifications", language: appLanguage)) {
            notificationRow("prayer_fajr", "sunrise", $fajrEnabled, $fajrSound)
            SettingsDivider()
            notificationRow("prayer_sunrise", "sunrise.fill", $sunriseEnabled, $sunriseSound)
            SettingsDivider()
            notificationRow("prayer_dhuhr", "sun.max.fill", $dhuhrEnabled, $dhuhrSound)
            SettingsDivider()
            notificationRow("prayer_asr", "sun.min.fill", $asrEnabled, $asrSound)
            SettingsDivider()
            notificationRow("prayer_maghrib", "sunset.fill", $maghribEnabled, $maghribSound)
            SettingsDivider()
            notificationRow("prayer_isha", "moon.stars.fill", $ishaEnabled, $ishaSound)
        }

        SettingsCard(title: Translations.string("timing", language: appLanguage)) {
            SettingsRow(title: Translations.string("prayer_reminder", language: appLanguage)) {
                Picker("", selection: $reminderInterval) {
                    Text(Translations.string("reminder_disabled", language: appLanguage)).tag(0)
                    Text(Translations.string("reminder_10_minutes", language: appLanguage)).tag(10)
                    Text(Translations.string("reminder_15_minutes", language: appLanguage)).tag(15)
                    Text(Translations.string("reminder_20_minutes", language: appLanguage)).tag(20)
                    Text(Translations.string("reminder_30_minutes", language: appLanguage)).tag(30)
                    Text(Translations.string("reminder_1_hour", language: appLanguage)).tag(60)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            SettingsDivider()

            SettingsRow(title: Translations.string("menu_bar_warning", language: appLanguage)) {
                Picker("", selection: $warningInterval) {
                    Text(Translations.string("warning_disabled", language: appLanguage)).tag(0)
                    Text(Translations.string("warning_10_minutes", language: appLanguage)).tag(10)
                    Text(Translations.string("warning_15_minutes", language: appLanguage)).tag(15)
                    Text(Translations.string("warning_20_minutes", language: appLanguage)).tag(20)
                    Text(Translations.string("warning_25_minutes", language: appLanguage)).tag(25)
                    Text(Translations.string("warning_30_minutes", language: appLanguage)).tag(30)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
        }
        // The denial banner was captured once at launch and never re-read, so granting
        // permission in System Settings left a stale warning on screen.
        .onAppear { manager.refreshAuthorizationStatus() }
    }

    private func notificationRow(_ nameKey: String,
                                 _ icon: String,
                                 _ isEnabled: Binding<Bool>,
                                 _ sound: Binding<String>) -> some View {
        PrayerNotificationRow(prayerName: Translations.string(nameKey, language: appLanguage),
                              icon: icon,
                              isEnabled: isEnabled,
                              soundRawValue: sound,
                              appLanguage: appLanguage)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
                VStack(alignment: .leading, spacing: 2) {
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
                .frame(width: 60, alignment: .leading)
            
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
