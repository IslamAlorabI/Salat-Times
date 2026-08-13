import Foundation

// Names of the Aladhan calculation methods.
nonisolated let methodStrings: [String: [String: String]] = [
    "method_karachi": [
        "ar": "جامعة كراتشي",
        "en": "University of Karachi",
        "ru": "Университет Карачи",
        "id": "Universitas Karachi",
        "tr": "Karaçi Üniversitesi",
        "ur": "جامعہ کراچی",
        "fa": "دانشگاه کراچی",
        "de": "Universität Karachi"
    ],
    "method_isna": [
        "ar": "أمريكا الشمالية (ISNA)",
        "en": "North America (ISNA)",
        "ru": "Северная Америка (ISNA)",
        "id": "Amerika Utara (ISNA)",
        "tr": "Kuzey Amerika (ISNA)",
        "ur": "شمالی امریکہ (ISNA)",
        "fa": "آمریکای شمالی (ISNA)",
        "de": "Nordamerika (ISNA)"
    ],
    "method_mwl": [
        "ar": "رابطة العالم الإسلامي",
        "en": "Muslim World League",
        "ru": "Всемирная исламская лига",
        "id": "Liga Muslim Dunia",
        "tr": "Müslüman Dünya Ligi",
        "ur": "مسلم ورلڈ لیگ",
        "fa": "اتحادیه جهان اسلام",
        "de": "Muslimische Weltliga"
    ],
    "method_umm_al_qura": [
        "ar": "أم القرى - مكة",
        "en": "Umm Al-Qura - Makkah",
        "ru": "Умм аль-Кура - Мекка",
        "id": "Umm Al-Qura - Makkah",
        "tr": "Umm Al-Qura - Mekke",
        "ur": "ام القریٰ - مکہ",
        "fa": "ام القری - مکه",
        "de": "Umm Al-Qura - Mekka"
    ],
    "method_egyptian": [
        "ar": "الهيئة العامة المصرية",
        "en": "Egyptian General Authority",
        "ru": "Египетское генеральное управление",
        "id": "Otoritas Umum Mesir",
        "tr": "Mısır Genel Otoritesi",
        "ur": "مصری جنرل اتھارٹی",
        "fa": "هیئت عمومی مصر",
        "de": "Ägyptische Generalbehörde"
    ],
    "method_tehran": [
        "ar": "جامعة طهران",
        "en": "University of Tehran",
        "ru": "Университет Тегерана",
        "id": "Universitas Tehran",
        "tr": "Tahran Üniversitesi",
        "ur": "جامعہ تہران",
        "fa": "دانشگاه تهران",
        "de": "Universität Teheran"
    ],
    "method_gulf": [
        "ar": "منطقة الخليج",
        "en": "Gulf Region",
        "ru": "Персидский залив",
        "id": "Wilayah Teluk",
        "tr": "Körfez Bölgesi",
        "ur": "خلیجی خطہ",
        "fa": "منطقه خلیج",
        "de": "Golfregion"
    ],
    "method_kuwait": [
        "ar": "الكويت",
        "en": "Kuwait",
        "ru": "Кувейт",
        "id": "Kuwait",
        "tr": "Kuveyt",
        "ur": "کویت",
        "fa": "کویت",
        "de": "Kuwait"
    ],
    "method_qatar": [
        "ar": "قطر",
        "en": "Qatar",
        "ru": "Катар",
        "id": "Qatar",
        "tr": "Katar",
        "ur": "قطر",
        "fa": "قطر",
        "de": "Katar"
    ],
    "method_singapore": [
        "ar": "سنغافورة (MUIS)",
        "en": "Singapore (MUIS)",
        "ru": "Сингапур (MUIS)",
        "id": "Singapura (MUIS)",
        "tr": "Singapur (MUIS)",
        "ur": "سنگاپور (MUIS)",
        "fa": "سنگاپور (MUIS)",
        "de": "Singapur (MUIS)"
    ],
    "method_france": [
        "ar": "فرنسا (UOIF)",
        "en": "France (UOIF)",
        "ru": "Франция (UOIF)",
        "id": "Prancis (UOIF)",
        "tr": "Fransa (UOIF)",
        "ur": "فرانس (UOIF)",
        "fa": "فرانسه (UOIF)",
        "de": "Frankreich (UOIF)"
    ],
    "method_turkey": [
        "ar": "تركيا (ديانت)",
        "en": "Turkey (Diyanet)",
        "ru": "Турция (Диянет)",
        "id": "Turki (Diyanet)",
        "tr": "Türkiye (Diyanet)",
        "ur": "ترکی (دیانت)",
        "fa": "ترکیه (دیانت)",
        "de": "Türkei (Diyanet)"
    ],
    "method_russia": [
        "ar": "روسيا",
        "en": "Russia",
        "ru": "Россия",
        "id": "Rusia",
        "tr": "Rusya",
        "ur": "روس",
        "fa": "روسیه",
        "de": "Russland"
    ],
    "method_moonsighting": [
        "ar": "لجنة رؤية الهلال",
        "en": "Moonsighting Committee",
        "ru": "Комитет наблюдения Луны",
        "id": "Komite Rukyatul Hilal",
        "tr": "Hilal Gözlem Komitesi",
        "ur": "رویت ہلال کمیٹی",
        "fa": "کمیته رویت هلال",
        "de": "Mondsichtungskomitee"
    ],
    "method_dubai": [
        "ar": "دبي",
        "en": "Dubai",
        "ru": "Дубай",
        "id": "Dubai",
        "tr": "Dubai",
        "ur": "دبئی",
        "fa": "دبی",
        "de": "Dubai"
    ],
    "method_malaysia": [
        "ar": "ماليزيا (JAKIM)",
        "en": "Malaysia (JAKIM)",
        "ru": "Малайзия (JAKIM)",
        "id": "Malaysia (JAKIM)",
        "tr": "Malezya (JAKIM)",
        "ur": "ملائیشیا (JAKIM)",
        "fa": "مالزی (JAKIM)",
        "de": "Malaysia (JAKIM)"
    ],
    "method_tunisia": [
        "ar": "تونس",
        "en": "Tunisia",
        "ru": "Тунис",
        "id": "Tunisia",
        "tr": "Tunus",
        "ur": "تیونس",
        "fa": "تونس",
        "de": "Tunesien"
    ],
    "method_algeria": [
        "ar": "الجزائر",
        "en": "Algeria",
        "ru": "Алжир",
        "id": "Aljazair",
        "tr": "Cezayir",
        "ur": "الجزائر",
        "fa": "الجزایر",
        "de": "Algerien"
    ],
    "method_indonesia": [
        "ar": "إندونيسيا (KEMENAG)",
        "en": "Indonesia (KEMENAG)",
        "ru": "Индонезия (KEMENAG)",
        "id": "Indonesia (KEMENAG)",
        "tr": "Endonezya (KEMENAG)",
        "ur": "انڈونیشیا (KEMENAG)",
        "fa": "اندونزی (KEMENAG)",
        "de": "Indonesien (KEMENAG)"
    ],
    "method_morocco": [
        "ar": "المغرب",
        "en": "Morocco",
        "ru": "Марокко",
        "id": "Maroko",
        "tr": "Fas",
        "ur": "مراکش",
        "fa": "مراکش",
        "de": "Marokko"
    ],
    "method_portugal": [
        "ar": "البرتغال",
        "en": "Portugal",
        "ru": "Португалия",
        "id": "Portugal",
        "tr": "Portekiz",
        "ur": "پرتگال",
        "fa": "پرتغال",
        "de": "Portugal"
    ],
    "method_jordan": [
        "ar": "الأردن",
        "en": "Jordan",
        "ru": "Иордания",
        "id": "Yordania",
        "tr": "Ürdün",
        "ur": "اردن",
        "fa": "اردن",
        "de": "Jordanien"
    ],
]

