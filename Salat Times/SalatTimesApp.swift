//
//  SalatTimesApp.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI

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
        }
        .windowResizability(.contentSize)
    }
}
