//
//  SalatTimesApp.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI
import AppKit

@main
struct SalatTimesApp: App {
    // هنا بنخلق "المدير" لأول مرة
    @StateObject private var manager = PrayerManager()
    
    var body: some Scene {
        // أيقونة البار العلوي
        MenuBarExtra("Salat Times", systemImage: "moon.stars.fill") {
            ContentView()
                .environmentObject(manager) // بندي المدير للواجهة عشان تعرض البيانات
        }
        .menuBarExtraStyle(.window)
        
        // نافذة الإعدادات
        Window("الإعدادات", id: "settings") {
            SettingsView()
                .environmentObject(manager)
                .onAppear {
                    // تفعيل التطبيق وجعل النافذة في المقدمة
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 600)
    }
}
