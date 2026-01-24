import SwiftUI
import CoreLocation
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("calculationMethod") private var method = 5
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    
    // Notification settings per prayer
    @AppStorage("notification_Fajr_enabled") private var fajrEnabled = true
    @AppStorage("notification_Dhuhr_enabled") private var dhuhrEnabled = true
    @AppStorage("notification_Asr_enabled") private var asrEnabled = true
    @AppStorage("notification_Maghrib_enabled") private var maghribEnabled = true
    @AppStorage("notification_Isha_enabled") private var ishaEnabled = true
    
    @AppStorage("notification_Fajr_sound") private var fajrSound = "default"
    @AppStorage("notification_Dhuhr_sound") private var dhuhrSound = "default"
    @AppStorage("notification_Asr_sound") private var asrSound = "default"
    @AppStorage("notification_Maghrib_sound") private var maghribSound = "default"
    @AppStorage("notification_Isha_sound") private var ishaSound = "default"
    
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                GroupBox(label: Label(Translations.string("language_ar", language: appLanguage) + " / " + Translations.string("language_en", language: appLanguage), systemImage: "globe")) {
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
                
                GroupBox(label: Label(Translations.string("location", language: appLanguage), systemImage: "location.fill")) {
                    Picker("", selection: $selectedCityRaw) {
                        ForEach(City.allCases) { city in
                            Text(city.getName(language: appLanguage))
                                .tag(city.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                GroupBox(label: Label(Translations.string("calculation_method", language: appLanguage), systemImage: "function")) {
                    Picker("", selection: $method) {
                        Text(Translations.string("method_egyptian", language: appLanguage)).tag(5)
                        Text(Translations.string("method_umm_al_qura", language: appLanguage)).tag(4)
                        Text(Translations.string("method_mwl", language: appLanguage)).tag(3)
                        Text(Translations.string("method_isna", language: appLanguage)).tag(2)
                    }
                    .pickerStyle(.radioGroup)
                }
                
                GroupBox(label: Label(Translations.string("time_format", language: appLanguage), systemImage: "clock")) {
                    Picker("", selection: $is24HourFormat) {
                        Text("24H (18:00)").tag(true)
                        Text("12H (6:00 PM)").tag(false)
                    }
                    .pickerStyle(.segmented)
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
                    Text("Made with ♥︎ by Islam AlorabI - 2026")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .padding()
        }
        .frame(width: 420, height: 680)
        .background(.regularMaterial)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        .onChange(of: selectedCityRaw) { _ in manager.loadSavedCity() }
        .onChange(of: method) { _ in manager.loadSavedCity() }
        // Reschedule notifications when any notification setting changes
        .onChange(of: fajrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: dhuhrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: asrEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: maghribEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: ishaEnabled) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: fajrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: dhuhrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: asrSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: maghribSound) { _ in manager.schedulePrayerNotifications() }
        .onChange(of: ishaSound) { _ in manager.schedulePrayerNotifications() }
    }
}

// MARK: - Language Radio Button Component
struct LanguageRadioButton: View {
    let title: String
    let tag: String
    @Binding var selection: String
    
    var body: some View {
        Button(action: {
            selection = tag
        }) {
            HStack(spacing: 6) {
                Image(systemName: selection == tag ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(selection == tag ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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

enum City: String, CaseIterable, Identifiable {
    case cairo = "Cairo"
    case riyadh = "Riyadh"
    case newYork = "New York"
    case kafrElSheikh = "Kafr El-Sheikh"
    case algiers = "Algiers"
    
    var id: String { self.rawValue }
    
    func getName(language: String) -> String {
        let names: [String: [String: String]] = [
            "Cairo": [
                "ar": "القاهرة، مصر",
                "en": "Cairo, Egypt",
                "ru": "Каир, Египет",
                "id": "Kairo, Mesir",
                "tr": "Kahire, Mısır",
                "ur": "قاہرہ، مصر",
                "fa": "قاهره، مصر",
                "de": "Kairo, Ägypten"
            ],
            "Riyadh": [
                "ar": "الرياض، السعودية",
                "en": "Riyadh, KSA",
                "ru": "Эр-Рияд, Саудовская Аравия",
                "id": "Riyadh, Arab Saudi",
                "tr": "Riyad, Suudi Arabistan",
                "ur": "ریاض، سعودی عرب",
                "fa": "ریاض، عربستان",
                "de": "Riad, Saudi-Arabien"
            ],
            "New York": [
                "ar": "نيويورك، أمريكا",
                "en": "New York, USA",
                "ru": "Нью-Йорк, США",
                "id": "New York, Amerika Serikat",
                "tr": "New York, ABD",
                "ur": "نیویارک، امریکہ",
                "fa": "نیویورک، آمریکا",
                "de": "New York, USA"
            ],
            "Kafr El-Sheikh": [
                "ar": "كفر الشيخ، مصر",
                "en": "Kafr El-Sheikh, Egypt",
                "ru": "Кафр-эш-Шейх, Египет",
                "id": "Kafr El-Sheikh, Mesir",
                "tr": "Kafr El-Sheikh, Mısır",
                "ur": "کفر الشیخ، مصر",
                "fa": "کفر الشیخ، مصر",
                "de": "Kafr El-Sheikh, Ägypten"
            ],
            "Algiers": [
                "ar": "الجزائر العاصمة",
                "en": "Algiers, Algeria",
                "ru": "Алжир, Алжир",
                "id": "Aljir, Aljazair",
                "tr": "Cezayir, Cezayir",
                "ur": "الجزائر، الجزائر",
                "fa": "الجزایر، الجزایر",
                "de": "Algier, Algerien"
            ]
        ]
        return names[self.rawValue]?[language] ?? names[self.rawValue]?["en"] ?? self.rawValue
    }
    
    var coordinates: CLLocationCoordinate2D {
        switch self {
        case .cairo: return CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)
        case .riyadh: return CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        case .newYork: return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        case .kafrElSheikh: return CLLocationCoordinate2D(latitude: 31.1107, longitude: 30.9388)
        case .algiers: return CLLocationCoordinate2D(latitude: 36.7528, longitude: 3.0420)
        }
    }
}
