
import SwiftUI
import AppKit

@main
struct SalatTimesApp: App {
    @StateObject private var manager = PrayerManager()
    
    var body: some Scene {
        MenuBarExtra("Salat Times", systemImage: "moon.stars.fill") {
            ContentView()
                .environmentObject(manager)
        }
        .menuBarExtraStyle(.window)
        
        Window("الإعدادات", id: "settings") {
            SettingsView()
                .environmentObject(manager)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "الإعدادات" || $0.title == "Settings" }) {
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
