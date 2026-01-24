
import SwiftUI
import AppKit

@main
struct SalatTimesApp: App {
    @StateObject private var manager = PrayerManager()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .imageScale(.small)
                Text(manager.menuBarTitle)
                    .font(.system(size: 11))
            }
        }
        .menuBarExtraStyle(.window)
        
        Window(Translations.string("settings", language: UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"), id: "settings") {
            SettingsView()
                .environmentObject(manager)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"
                    let settingsTitle = Translations.string("settings", language: appLanguage)
                    if let window = NSApplication.shared.windows.first(where: { $0.title == settingsTitle }) {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.hasShadow = true
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
        .windowStyle(.hiddenTitleBar)
    }
}
