//
//  Untitled.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // --- الهيدر ---
            HStack {
                VStack(alignment: .leading) {
                    Text("مواقيت الصلاة")
                        .font(.headline)
                    Text(manager.city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // زر التحديث (Refresh)
                Button(action: {
                    manager.loadSavedCity() // إعادة تحميل البيانات
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("تحديث البيانات")
                
                SizedBox(width: 10) // مسافة صغيرة
                
                // زر الموقع (تفعيل المدينة المختارة)
                Button(action: {
                    manager.loadSavedCity() // يجيب المدينة من الإعدادات
                }) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("تطبيق المدينة المختارة من الإعدادات")
            }
            .padding()
            .background(Color.white.opacity(0.1))
            
            Divider()
            
            // --- المحتوى ---
            if manager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("جاري التحميل...")
                    Spacer()
                }
            } else if let error = manager.errorMessage {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                    Button("حاول مرة أخرى") {
                        manager.loadSavedCity()
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 2) {
                    PrayerRow(name: "الفجر", time: manager.timings["Fajr"] ?? "--", icon: "sunrise")
                    PrayerRow(name: "الظهر", time: manager.timings["Dhuhr"] ?? "--", icon: "sun.max")
                    PrayerRow(name: "العصر", time: manager.timings["Asr"] ?? "--", icon: "sun.min")
                    PrayerRow(name: "المغرب", time: manager.timings["Maghrib"] ?? "--", icon: "sunset")
                    PrayerRow(name: "العشاء", time: manager.timings["Isha"] ?? "--", icon: "moon.stars")
                }
                .padding(.vertical, 15)
            }
            
            Spacer()
            Divider()
            
            // --- الفوتر ---
            HStack {
                Text("v1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("الإعدادات") {
                    openWindow(id: "settings")
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(10)
        }
        // كبرنا الحجم هنا (عرض 320 بدل 280)
        .frame(width: 320, height: 400)
        .background(.ultraThinMaterial)
    }
}

// عنصر مساعد للمسافات (موجود في Flutter وحبينا نجيبه هنا)
struct SizedBox: View {
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var body: some View { Spacer().frame(width: width, height: height) }
}

struct PrayerRow: View {
    let name: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 25) // كبرنا الأيقونة سنة
                .foregroundColor(.secondary)
            Text(name)
                .font(.system(size: 15)) // كبرنا الخط سنة
            Spacer()
            Text(time)
                .fontWeight(.bold)
                .monospacedDigit()
                .font(.system(size: 15))
        }
        .padding(.horizontal, 20) // وسعنا الحواف
        .padding(.vertical, 8)
    }
}
