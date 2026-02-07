
import SwiftUI
import AppKit

@main
struct SalatTimesApp: App {
    @StateObject private var manager = PrayerManager()
    @AppStorage("hasShownWelcome") private var hasShownWelcome = false
    @Environment(\.openWindow) var openWindow
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(manager)
                .onAppear {
                    if !hasShownWelcome {
                        openWindow(id: "welcome")
                    }
                }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: manager.isWarningActive ? "bell.badge.fill" : "moon.stars.fill")
                    .imageScale(.small)
                    .symbolRenderingMode(.multicolor)
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
        
        Window("Welcome", id: "welcome") {
            WelcomeView()
                .environmentObject(manager)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<WelcomeView> }) ?? false }) {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.hasShadow = true
                        window.titleVisibility = .hidden
                        window.titlebarAppearsTransparent = true
                        window.styleMask.insert(.fullSizeContentView)
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 500)
        .windowStyle(.hiddenTitleBar)
    }
}
