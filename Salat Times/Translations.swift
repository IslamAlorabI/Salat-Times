import Foundation

nonisolated struct Translations {
    /// Every domain table merged once, lazily, instead of rebuilt on each lookup.
    private static let all: [String: [String: String]] = {
        var merged: [String: [String: String]] = [:]
        for table in [uiStrings, methodStrings, prayerStrings, hijriStrings, settingsStrings] {
            merged.merge(table) { _, new in new }
        }
        return merged
    }()

    static func string(_ key: String, language: String) -> String {
        return all[key]?[language] ?? all[key]?["en"] ?? key
    }

    static func isRTL(_ language: String) -> Bool {
        return ["ar", "ur", "fa"].contains(language)
    }
    
    static func locale(_ language: String) -> String {
        return language
    }
    
    static func hijriMonthName(_ monthNumber: Int, language: String) -> String {
        let monthKeys = [
            1: "hijri_muharram",
            2: "hijri_safar",
            3: "hijri_rabi_al_awwal",
            4: "hijri_rabi_al_thani",
            5: "hijri_jumada_al_awwal",
            6: "hijri_jumada_al_thani",
            7: "hijri_rajab",
            8: "hijri_shaban",
            9: "hijri_ramadan",
            10: "hijri_shawwal",
            11: "hijri_dhul_qadah",
            12: "hijri_dhul_hijjah"
        ]
        guard let key = monthKeys[monthNumber] else { return "" }
        return string(key, language: language)
    }
    
    static func localizedNumber(_ number: String, numberFormat: String) -> String {
        guard numberFormat != "western" else { return number }
        
        let arabicNumerals: [Character: Character] = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        
        let persianNumerals: [Character: Character] = [
            "0": "۰", "1": "۱", "2": "۲", "3": "۳", "4": "۴",
            "5": "۵", "6": "۶", "7": "۷", "8": "۸", "9": "۹"
        ]
        
        let numerals = (numberFormat == "arabic") ? arabicNumerals : persianNumerals
        
        return String(number.map { numerals[$0] ?? $0 })
    }
}
