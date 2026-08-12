
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
                // The brand mosque is a template image, so it inverts for dark mode and
                // dims with the menu bar on its own. The warning state stays an SF Symbol —
                // it carries colour and urgency that a template image cannot.
                if manager.isWarningActive {
                    Image(systemName: "bell.badge.fill")
                        .imageScale(.small)
                        .symbolRenderingMode(.multicolor)
                } else {
                    Image("MenuBarIcon")
                }
                Text(manager.menuBarTitle)
                    .font(.system(size: 11))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
        
        Window(Translations.string("settings", language: UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"), id: "settings") {
            SettingsView()
                .environmentObject(manager)
                // Opacity is *not* forced here any more. `SettingsView` drives it from the
                // translucency setting through `WindowOpacityConfigurator`; hardcoding a
                // clear background here meant every pixel the view did not paint — the
                // seam between sidebar and pane — rendered as a black band.
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        // `.contentMinSize`, not `.contentSize`: the sidebar layout wants to be widened,
        // and `.contentSize` pins the window to exactly the content's ideal size.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 640)
        .windowStyle(.hiddenTitleBar)
        
        // Resizable, unlike the other two: a month of times is content the user may well
        // want wider, and `.contentSize` would pin it shut.
        Window(Translations.string("monthly_schedule", language: UserDefaults.standard.string(forKey: "appLanguage") ?? "ar"), id: "schedule") {
            MonthlyScheduleView()
                .environmentObject(manager)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 820, height: 620)

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
