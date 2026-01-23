//
//  PrayerManager.swift
//  Salat Times
//
//  Created by Islam AlorabI on 1/23/26.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

struct PrayerResponse: Codable {
    let code: Int
    let status: String
    let data: PrayerData
}

struct PrayerData: Codable {
    let timings: [String: String]
    let meta: PrayerMeta
}

struct PrayerMeta: Codable {
    let timezone: String
}

class PrayerManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var timings: [String: String] = [:]
    @Published var isLoading = true
    @Published var city: String = "جاري التحميل..."
    @Published var errorMessage: String? = nil
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        
        // التغيير هنا: أول ما يفتح، يحمل المدينة المحفوظة فوراً (أو القاهرة كافتراضي)
        loadSavedCity()
    }
    
    // الوظيفة السحرية الجديدة: بتقرأ من الإعدادات وتجيب البيانات
    func loadSavedCity() {
        self.isLoading = true
        self.errorMessage = nil
        
        // قراءة المدينة المحفوظة في الإعدادات
        let savedCityRaw = UserDefaults.standard.string(forKey: "selectedCityRaw") ?? City.cairo.rawValue
        
        // البحث عن إحداثيات المدينة دي
        if let cityEnum = City.allCases.first(where: { $0.rawValue == savedCityRaw }) {
            self.city = cityEnum.rawValue
            let coords = cityEnum.coordinates
            print("🌍 تحميل بيانات المدينة اليدوية: \(cityEnum.rawValue)")
            fetchPrayerTimes(lat: coords.latitude, lon: coords.longitude)
        } else {
            // لو فشل، شغل الـ GPS كخطة بديلة
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }
    }
    
    // دالة الـ GPS (احتياطي)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationManager.stopUpdatingLocation()
        
        // لو المستخدم مش مختار مدينة يدوية، نستخدم موقعه الحالي
        // (ممكن نعدل اللوجيك ده لاحقاً، بس حالياً التركيز على المدن اليدوية)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ GPS Error: \(error.localizedDescription)")
        // لو الـ GPS فشل، حمل القاهرة
        loadSavedCity()
    }
    
    func fetchPrayerTimes(lat: Double, lon: Double) {
        // قراءة طريقة الحساب من الإعدادات
        let method = UserDefaults.standard.integer(forKey: "calculationMethod")
        let actualMethod = method == 0 ? 5 : method // لو صفر خليها 5 (مصر)
        
        let urlString = "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=\(actualMethod)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "تأكد من الاتصال بالإنترنت"
                    self.isLoading = false
                }
                return
            }
            
            if let data = data {
                if let decoded = try? JSONDecoder().decode(PrayerResponse.self, from: data) {
                    DispatchQueue.main.async {
                        self.timings = decoded.data.timings
                        self.isLoading = false
                    }
                }
            }
        }.resume()
    }
}
