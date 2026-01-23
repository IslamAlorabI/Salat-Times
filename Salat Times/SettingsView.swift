//
//  SettingsView.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import SwiftUI
import CoreLocation

struct SettingsView: View {
    @AppStorage("calculationMethod") private var method = 5
    // هنا بنحفظ "النص" بتاع اسم المدينة عشان نعرف نقراه هناك
    @AppStorage("selectedCityRaw") private var selectedCityRaw = City.cairo.rawValue
    
    var body: some View {
        Form {
            Section(header: Text("إعدادات الموقع")) {
                Picker("المدينة", selection: $selectedCityRaw) {
                    ForEach(City.allCases) { city in
                        Text(city.rawValue).tag(city.rawValue)
                    }
                }
            }
            
            Section(header: Text("إعدادات الحساب")) {
                Picker("طريقة الحساب", selection: $method) {
                    Text("الهيئة العامة المصرية").tag(5)
                    Text("أم القرى - مكة").tag(4)
                    Text("رابطة العالم الإسلامي").tag(3)
                    Text("أمريكا الشمالية").tag(2)
                }
            }
            
            Section {
                Text("بعد تغيير المدينة، اضغط على أيقونة الموقع في الواجهة الرئيسية للتحديث.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
}

// قائمة المدن (مهمة جداً تكون هنا عشان الملفين يشوفوها)
enum City: String, CaseIterable, Identifiable {
    case cairo = "القاهرة، مصر"
    case riyadh = "الرياض، السعودية"
    case newYork = "نيويورك، أمريكا"
    case kafrElSheikh = "كفر الشيخ، مصر"
    case algiers = "الجزائر العاصمة"
    
    var id: String { self.rawValue }
    
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
