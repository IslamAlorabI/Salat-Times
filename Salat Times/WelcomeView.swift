
import SwiftUI
import ServiceManagement

struct WelcomeView: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep: OnboardingStep = .welcome
    
    // Settings States
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    @AppStorage("calculationMethod") private var method = 5
    @AppStorage("timeFormat24") private var is24HourFormat = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("notification_Fajr_enabled") private var fajrEnabled = true
    @AppStorage("notification_Sunrise_enabled") private var sunriseEnabled = true
    @AppStorage("notification_Dhuhr_enabled") private var dhuhrEnabled = true
    @AppStorage("notification_Asr_enabled") private var asrEnabled = true
    @AppStorage("notification_Maghrib_enabled") private var maghribEnabled = true
    @AppStorage("notification_Isha_enabled") private var ishaEnabled = true
    
    enum OnboardingStep {
        case welcome
        case settings
    }
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.accentColor.opacity(0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                if currentStep == .welcome {
                    welcomeStep
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    settingsStep
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.5), value: currentStep)
        }
        .frame(width: 600, height: 500)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
    }
    
    // MARK: - Step 1: Welcome
    var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Icon
            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .shadow(radius: 10)
            
            // Title & Description
            VStack(spacing: 16) {
                Text(Translations.string("welcome_title", language: appLanguage))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(Translations.string("app_description", language: appLanguage))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    currentStep = .settings
                }
            } label: {
                Text(Translations.string("get_started", language: appLanguage))
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Step 2: Settings Configuration
    var settingsStep: some View {
        VStack(spacing: 0) {
            // Header
            Text(Translations.string("welcome_settings_header", language: appLanguage))
                .font(.title2.bold())
                .padding(.top, 30)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Language
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Translations.string("languages", language: appLanguage))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
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
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    
                    // Location & Method
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Translations.string("location", language: appLanguage))
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        CitySearchPicker(selectedCityRaw: $selectedCityRaw, appLanguage: appLanguage)
                        
                        Divider().padding(.vertical, 5)
                        
                        CalculationMethodPicker(selectedMethod: $method, appLanguage: appLanguage)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    
                    // Preferences
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Translations.string("general", language: appLanguage))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            
                        HStack {
                            Text(Translations.string("time_format", language: appLanguage))
                            Spacer()
                            HStack(spacing: 0) {
                                TimeFormatRadioButton(title: "24H", isSelected: is24HourFormat) { is24HourFormat = true }
                                Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 16).padding(.horizontal, 8)
                                TimeFormatRadioButton(title: "12H", isSelected: !is24HourFormat) { is24HourFormat = false }
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text(Translations.string("launch_at_login", language: appLanguage))
                            Spacer()
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                        }
                        .onChange(of: launchAtLogin) { newValue in
                            do {
                                if newValue { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch {
                                launchAtLogin = !newValue
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            
            // Footer Action
            VStack {
                Divider()
                HStack {
                    Button(Translations.string("change", language: appLanguage)) { // Back button essentially
                         withAnimation { currentStep = .welcome }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        hasShownWelcome = true
                        // Close window logic handled by parent or window controller
                        if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<WelcomeView> }) ?? false }) {
                            window.close()
                        }
                        // Ensure manager updates
                        manager.loadSavedCity()
                        manager.schedulePrayerNotifications()
                    } label: {
                        Text(Translations.string("finish_setup", language: appLanguage))
                            .font(.headline)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
        }
    }
}
