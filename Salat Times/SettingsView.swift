
import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("calculationMethod") private var method = 5
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("timeFormat24") private var is24HourFormat = true
    
    @State private var testPrayerNameInput: String = ""
    @State private var testPrayerDate: Date = Date().addingTimeInterval(60)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                GroupBox(label: Label("اللغة / Language", systemImage: "globe")) {
                    Picker("", selection: $appLanguage) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                }
                
                GroupBox(label: Label(appLanguage == "ar" ? "الموقع" : "Location", systemImage: "location.fill")) {
                    Picker("", selection: $selectedCityRaw) {
                        ForEach(City.allCases) { city in
                            Text(appLanguage == "ar" ? city.arabicName : city.englishName)
                                .tag(city.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                GroupBox(label: Label(appLanguage == "ar" ? "طريقة الحساب" : "Calculation Method", systemImage: "function")) {
                    Picker("", selection: $method) {
                        Text(appLanguage == "ar" ? "الهيئة العامة المصرية" : "Egyptian General Authority").tag(5)
                        Text(appLanguage == "ar" ? "أم القرى - مكة" : "Umm Al-Qura - Makkah").tag(4)
                        Text(appLanguage == "ar" ? "رابطة العالم الإسلامي" : "Muslim World League").tag(3)
                        Text(appLanguage == "ar" ? "أمريكا الشمالية" : "North America (ISNA)").tag(2)
                    }
                    .pickerStyle(.radioGroup)
                }
                
                GroupBox(label: Label(appLanguage == "ar" ? "تنسيق الوقت" : "Time Format", systemImage: "clock")) {
                    Picker("", selection: $is24HourFormat) {
                        Text("24H (18:00)").tag(true)
                        Text("12H (6:00 PM)").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                
                GroupBox(label: Label(appLanguage == "ar" ? "صلاة تجريبية (للاختبار)" : "Test Prayer (for testing)", systemImage: "bell.badge")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let testTime = manager.testPrayerTime, !manager.testPrayerName.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(appLanguage == "ar" ? "صلاة تجريبية نشطة:" : "Active test prayer:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text(manager.testPrayerName)
                                        .font(.system(size: 14, weight: .semibold))
                                    Spacer()
                                    Text(formatTestTime(testTime))
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.blue)
                                }
                                
                                Button(action: {
                                    manager.removeTestPrayer()
                                }) {
                                    Label(appLanguage == "ar" ? "حذف الصلاة التجريبية" : "Remove Test Prayer", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField(appLanguage == "ar" ? "اسم الصلاة (مثال: صلاة عيد الأضحى)" : "Prayer name (e.g., Eid Al-Adha)", text: $testPrayerNameInput)
                                    .textFieldStyle(.roundedBorder)
                                
                                DatePicker(
                                    appLanguage == "ar" ? "الوقت:" : "Time:",
                                    selection: $testPrayerDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                                
                                Button(action: {
                                    if !testPrayerNameInput.isEmpty {
                                        manager.addTestPrayer(name: testPrayerNameInput, time: testPrayerDate)
                                        testPrayerNameInput = ""
                                        testPrayerDate = Date().addingTimeInterval(60)
                                    }
                                }) {
                                    Label(appLanguage == "ar" ? "إضافة صلاة تجريبية" : "Add Test Prayer", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(testPrayerNameInput.isEmpty)
                            }
                        }
                    }
                }
                
                Divider()
                
                HStack {
                    Spacer()
                    Text("Made with ♥︎ by Islam AlorabI - 2026")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .opacity(0.8)
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding()
        }
        .frame(width: 400, height: 600)
        .background(.regularMaterial)
        .environment(\.layoutDirection, appLanguage == "ar" ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: appLanguage == "ar" ? "ar" : "en"))
    }
    
    func formatTestTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        if is24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: appLanguage == "ar" ? "ar" : "en")
        }
        return formatter.string(from: date)
    }
}

enum City: String, CaseIterable, Identifiable {
    case cairo = "Cairo"
    case riyadh = "Riyadh"
    case newYork = "New York"
    case kafrElSheikh = "Kafr El-Sheikh"
    case algiers = "Algiers"
    
    var id: String { self.rawValue }
    
    var arabicName: String {
        switch self {
        case .cairo: return "القاهرة، مصر"
        case .riyadh: return "الرياض، السعودية"
        case .newYork: return "نيويورك، أمريكا"
        case .kafrElSheikh: return "كفر الشيخ، مصر"
        case .algiers: return "الجزائر العاصمة"
        }
    }
    
    var englishName: String {
        switch self {
        case .cairo: return "Cairo, Egypt"
        case .riyadh: return "Riyadh, KSA"
        case .newYork: return "New York, USA"
        case .kafrElSheikh: return "Kafr El-Sheikh, Egypt"
        case .algiers: return "Algiers, Algeria"
        }
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
