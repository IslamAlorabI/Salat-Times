
import Foundation

struct Translations {
    static func string(_ key: String, language: String) -> String {
        let translations: [String: [String: String]] = [
            // Language names
            "language_ar": [
                "ar": "العربية",
                "en": "Arabic",
                "ru": "Арабский",
                "id": "Arab",
                "tr": "Arapça",
                "ur": "عربی",
                "fa": "عربی",
                "de": "Arabisch"
            ],
            "language_en": [
                "ar": "الإنجليزية",
                "en": "English",
                "ru": "Английский",
                "id": "Inggris",
                "tr": "İngilizce",
                "ur": "انگریزی",
                "fa": "انگلیسی",
                "de": "Englisch"
            ],
            "language_ru": [
                "ar": "الروسية",
                "en": "Russian",
                "ru": "Русский",
                "id": "Rusia",
                "tr": "Rusça",
                "ur": "روسی",
                "fa": "روسی",
                "de": "Russisch"
            ],
            "language_id": [
                "ar": "الإندونيسية",
                "en": "Indonesian",
                "ru": "Индонезийский",
                "id": "Indonesia",
                "tr": "Endonezce",
                "ur": "انڈونیشیائی",
                "fa": "اندونزیایی",
                "de": "Indonesisch"
            ],
            "language_tr": [
                "ar": "التركية",
                "en": "Turkish",
                "ru": "Турецкий",
                "id": "Turki",
                "tr": "Türkçe",
                "ur": "ترکی",
                "fa": "ترکی",
                "de": "Türkisch"
            ],
            "language_ur": [
                "ar": "الأردية",
                "en": "Urdu",
                "ru": "Урду",
                "id": "Urdu",
                "tr": "Urduca",
                "ur": "اردو",
                "fa": "اردو",
                "de": "Urdu"
            ],
            "language_fa": [
                "ar": "الفارسية",
                "en": "Persian",
                "ru": "Персидский",
                "id": "Persia",
                "tr": "Farsça",
                "ur": "فارسی",
                "fa": "فارسی",
                "de": "Persisch"
            ],
            "language_de": [
                "ar": "الألمانية",
                "en": "German",
                "ru": "Немецкий",
                "id": "Jerman",
                "tr": "Almanca",
                "ur": "جرمن",
                "fa": "آلمانی",
                "de": "Deutsch"
            ],
            
            // General settings
            "general": [
                "ar": "عام",
                "en": "General",
                "ru": "Общие",
                "id": "Umum",
                "tr": "Genel",
                "ur": "عمومی",
                "fa": "عمومی",
                "de": "Allgemein"
            ],
            "launch_at_login": [
                "ar": "تشغيل عند بدء النظام",
                "en": "Launch at Login",
                "ru": "Запускать при входе",
                "id": "Jalankan saat Login",
                "tr": "Girişte Başlat",
                "ur": "لاگ ان پر شروع کریں",
                "fa": "اجرا در ورود",
                "de": "Beim Anmelden starten"
            ],
            "languages": [
                "ar": "اللغات",
                "en": "Languages",
                "ru": "Языки",
                "id": "Bahasa",
                "tr": "Diller",
                "ur": "زبانیں",
                "fa": "زبان‌ها",
                "de": "Sprachen"
            ],
            
            // UI Strings
            "prayer_times_today": [
                "ar": "أوقات الصلاة اليوم",
                "en": "Prayer Times Today",
                "ru": "Времена молитвы сегодня",
                "id": "Waktu Sholat Hari Ini",
                "tr": "Bugünün Namaz Vakitleri",
                "ur": "آج کی نماز کے اوقات",
                "fa": "اوقات نماز امروز",
                "de": "Gebetszeiten heute"
            ],
            "refresh_data": [
                "ar": "تحديث البيانات",
                "en": "Refresh Data",
                "ru": "Обновить данные",
                "id": "Muat Ulang Data",
                "tr": "Verileri Yenile",
                "ur": "ڈیٹا تازہ کریں",
                "fa": "به‌روزرسانی داده‌ها",
                "de": "Daten aktualisieren"
            ],
            "retry": [
                "ar": "إعادة المحاولة",
                "en": "Retry",
                "ru": "Повторить",
                "id": "Coba Lagi",
                "tr": "Tekrar Dene",
                "ur": "دوبارہ کوشش کریں",
                "fa": "تلاش مجدد",
                "de": "Wiederholen"
            ],
            "settings": [
                "ar": "الإعدادات",
                "en": "Settings",
                "ru": "Настройки",
                "id": "Pengaturan",
                "tr": "Ayarlar",
                "ur": "ترتیبات",
                "fa": "تنظیمات",
                "de": "Einstellungen"
            ],
            "quit": [
                "ar": "إغلاق",
                "en": "Quit",
                "ru": "Выход",
                "id": "Keluar",
                "tr": "Çıkış",
                "ur": "بند کریں",
                "fa": "خروج",
                "de": "Beenden"
            ],
            "location": [
                "ar": "الموقع",
                "en": "Location",
                "ru": "Местоположение",
                "id": "Lokasi",
                "tr": "Konum",
                "ur": "مقام",
                "fa": "مکان",
                "de": "Standort"
            ],
            "calculation_method": [
                "ar": "طريقة الحساب",
                "en": "Calculation Method",
                "ru": "Метод расчета",
                "id": "Metode Perhitungan",
                "tr": "Hesaplama Yöntemi",
                "ur": "حساب کا طریقہ",
                "fa": "روش محاسبه",
                "de": "Berechnungsmethode"
            ],
            "time_format": [
                "ar": "تنسيق الوقت",
                "en": "Time Format",
                "ru": "Формат времени",
                "id": "Format Waktu",
                "tr": "Saat Formatı",
                "ur": "وقت کی شکل",
                "fa": "فرمت زمان",
                "de": "Zeitformat"
            ],
            "prayer_notifications": [
                "ar": "إشعارات الصلوات",
                "en": "Prayer Notifications",
                "ru": "Уведомления о молитве",
                "id": "Notifikasi Sholat",
                "tr": "Namaz Bildirimleri",
                "ur": "نماز کی اطلاعات",
                "fa": "اعلان‌های نماز",
                "de": "Gebetsbenachrichtigungen"
            ],
            "play_sound": [
                "ar": "تشغيل الصوت",
                "en": "Play Sound",
                "ru": "Воспроизвести звук",
                "id": "Putar Suara",
                "tr": "Sesi Çal",
                "ur": "آواز چلائیں",
                "fa": "پخش صدا",
                "de": "Ton abspielen"
            ],
            "prayer_time": [
                "ar": "حان وقت الصلاة",
                "en": "Prayer Time",
                "ru": "Время молитвы",
                "id": "Waktu Sholat",
                "tr": "Namaz Vakti",
                "ur": "نماز کا وقت",
                "fa": "وقت نماز",
                "de": "Gebetszeit"
            ],
            "prayer_time_body": [
                "ar": "حان وقت صلاة %@",
                "en": "It's time for %@ prayer",
                "ru": "Время для молитвы %@",
                "id": "Waktunya sholat %@",
                "tr": "%@ namazı vakti",
                "ur": "%@ نماز کا وقت ہے",
                "fa": "وقت نماز %@ است",
                "de": "Es ist Zeit für das %@ Gebet"
            ],
            "check_internet": [
                "ar": "تأكد من الاتصال بالإنترنت",
                "en": "Check your internet connection",
                "ru": "Проверьте подключение к интернету",
                "id": "Periksa koneksi internet Anda",
                "tr": "İnternet bağlantınızı kontrol edin",
                "ur": "اپنا انٹرنیٹ کنکشن چیک کریں",
                "fa": "اتصال اینترنت خود را بررسی کنید",
                "de": "Überprüfen Sie Ihre Internetverbindung"
            ],
            "search": [
                "ar": "بحث...",
                "en": "Search...",
                "ru": "Поиск...",
                "id": "Cari...",
                "tr": "Ara...",
                "ur": "تلاش...",
                "fa": "جستجو...",
                "de": "Suchen..."
            ],
            "change": [
                "ar": "تغيير",
                "en": "Change",
                "ru": "Изменить",
                "id": "Ubah",
                "tr": "Değiştir",
                "ur": "تبدیل کریں",
                "fa": "تغییر",
                "de": "Ändern"
            ],
            "loading": [
                "ar": "جاري التحميل...",
                "en": "Loading...",
                "ru": "Загрузка...",
                "id": "Memuat...",
                "tr": "Yükleniyor...",
                "ur": "لوڈ ہو رہا ہے...",
                "fa": "در حال بارگذاری...",
                "de": "Lädt..."
            ],
            
            // Welcome Screen
            "app_description": [
                "ar": "تطبيق بسيط وأنيق لمواقيت الصلاة في شريط القائمة.",
                "en": "A simple and elegant prayer times app in your menu bar.",
                "ru": "Простое и элегантное приложение времени молитвы.",
                "id": "Aplikasi waktu sholat yang sederhana dan elegan.",
                "tr": "Menü çubuğunuzda basit ve şık bir namaz vakitleri uygulaması.",
                "ur": "آپ کے مینو بار میں ایک سادہ اور خوبصورت نماز کے اوقات کی ایپ۔",
                "fa": "یک برنامه ساده و زیبا برای اوقات شرعی در نوار منو.",
                "de": "Eine einfache und elegante Gebetszeiten-App in Ihrer Menüleiste."
            ],
            "welcome_title": [
                "ar": "مرحباً بك في أوقات الصلاة",
                "en": "Welcome to Salat Times",
                "ru": "Добро пожаловать в Salat Times",
                "id": "Selamat datang di Salat Times",
                "tr": "Salat Times'a Hoş Geldiniz",
                "ur": "نماز کے اوقات میں خوش آمدید",
                "fa": "به اوقات صلاة خوش آمدید",
                "de": "Willkommen bei Salat Times"
            ],
            "get_started": [
                "ar": "ابدأ الآن",
                "en": "Get Started",
                "ru": "Начать",
                "id": "Mulai",
                "tr": "Başla",
                "ur": "شروع کریں",
                "fa": "شروع کنید",
                "de": "Loslegen"
            ],
            "finish_setup": [
                "ar": "إنهاء الإعداد",
                "en": "Finish Setup",
                "ru": "Завершить настройку",
                "id": "Selesai",
                "tr": "Kurulumu Tamamla",
                "ur": "سیٹ اپ مکمل کریں",
                "fa": "پایان تنظیمات",
                "de": "Einrichtung abschließen"
            ],
            "welcome_settings_header": [
                "ar": "دعنا نضبط إعداداتك",
                "en": "Let's set up your preferences",
                "ru": "Давайте настроим ваши предпочтения",
                "id": "Mari atur preferensi Anda",
                "tr": "Tercihlerinizi ayarlayalım",
                "ur": "آئیے اپنی ترجیحات ترتیب دیں",
                "fa": "بیایید ترجیحات شما را تنظیم کنیم",
                "de": "Lassen Sie uns Ihre Einstellungen einrichten"
            ],
            
            // Calculation methods
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
            
            // Prayer names
            "prayer_fajr": [
                "ar": "الفجر",
                "en": "Fajr",
                "ru": "Фаджр",
                "id": "Subuh",
                "tr": "Fecir",
                "ur": "فجر",
                "fa": "فجر",
                "de": "Fajr"
            ],
            "prayer_sunrise": [
                "ar": "الشروق",
                "en": "Sunrise",
                "ru": "Восход",
                "id": "Terbit",
                "tr": "Güneş",
                "ur": "طلوع آفتاب",
                "fa": "طلوع",
                "de": "Sonnenaufgang"
            ],
            "prayer_dhuhr": [
                "ar": "الظهر",
                "en": "Dhuhr",
                "ru": "Зухр",
                "id": "Dzuhur",
                "tr": "Öğle",
                "ur": "ظہر",
                "fa": "ظهر",
                "de": "Dhuhr"
            ],
            "prayer_asr": [
                "ar": "العصر",
                "en": "Asr",
                "ru": "Аср",
                "id": "Ashar",
                "tr": "İkindi",
                "ur": "عصر",
                "fa": "عصر",
                "de": "Asr"
            ],
            "prayer_maghrib": [
                "ar": "المغرب",
                "en": "Maghrib",
                "ru": "Магриб",
                "id": "Maghrib",
                "tr": "Akşam",
                "ur": "مغرب",
                "fa": "مغرب",
                "de": "Maghrib"
            ],
            "prayer_isha": [
                "ar": "العشاء",
                "en": "Isha",
                "ru": "Иша",
                "id": "Isya",
                "tr": "Yatsı",
                "ur": "عشاء",
                "fa": "عشاء",
                "de": "Isha"
            ],
            
            // Hijri months
            "hijri_muharram": [
                "ar": "محرم",
                "en": "Muharram",
                "ru": "Мухаррам",
                "id": "Muharram",
                "tr": "Muharrem",
                "ur": "محرم",
                "fa": "محرم",
                "de": "Muharram"
            ],
            "hijri_safar": [
                "ar": "صفر",
                "en": "Safar",
                "ru": "Сафар",
                "id": "Safar",
                "tr": "Safer",
                "ur": "صفر",
                "fa": "صفر",
                "de": "Safar"
            ],
            "hijri_rabi_al_awwal": [
                "ar": "ربيع الأول",
                "en": "Rabi' al-Awwal",
                "ru": "Раби аль-Авваль",
                "id": "Rabiul Awal",
                "tr": "Rebiülevvel",
                "ur": "ربیع الاول",
                "fa": "ربیع الاول",
                "de": "Rabi' al-Awwal"
            ],
            "hijri_rabi_al_thani": [
                "ar": "ربيع الثاني",
                "en": "Rabi' al-Thani",
                "ru": "Раби ас-Сани",
                "id": "Rabiul Akhir",
                "tr": "Rebiülahir",
                "ur": "ربیع الثانی",
                "fa": "ربیع الثانی",
                "de": "Rabi' al-Thani"
            ],
            "hijri_jumada_al_awwal": [
                "ar": "جمادى الأولى",
                "en": "Jumada al-Awwal",
                "ru": "Джумада аль-Уля",
                "id": "Jumadil Awal",
                "tr": "Cemaziyelevvel",
                "ur": "جمادی الاول",
                "fa": "جمادی الاول",
                "de": "Jumada al-Awwal"
            ],
            "hijri_jumada_al_thani": [
                "ar": "جمادى الآخرة",
                "en": "Jumada al-Thani",
                "ru": "Джумада ас-Сани",
                "id": "Jumadil Akhir",
                "tr": "Cemaziyelahir",
                "ur": "جمادی الثانی",
                "fa": "جمادی الثانی",
                "de": "Jumada al-Thani"
            ],
            "hijri_rajab": [
                "ar": "رجب",
                "en": "Rajab",
                "ru": "Раджаб",
                "id": "Rajab",
                "tr": "Recep",
                "ur": "رجب",
                "fa": "رجب",
                "de": "Rajab"
            ],
            "hijri_shaban": [
                "ar": "شعبان",
                "en": "Sha'ban",
                "ru": "Шаабан",
                "id": "Sya'ban",
                "tr": "Şaban",
                "ur": "شعبان",
                "fa": "شعبان",
                "de": "Sha'ban"
            ],
            "hijri_ramadan": [
                "ar": "رمضان",
                "en": "Ramadan",
                "ru": "Рамадан",
                "id": "Ramadan",
                "tr": "Ramazan",
                "ur": "رمضان",
                "fa": "رمضان",
                "de": "Ramadan"
            ],
            "hijri_shawwal": [
                "ar": "شوال",
                "en": "Shawwal",
                "ru": "Шавваль",
                "id": "Syawal",
                "tr": "Şevval",
                "ur": "شوال",
                "fa": "شوال",
                "de": "Schawwal"
            ],
            "hijri_dhul_qadah": [
                "ar": "ذو القعدة",
                "en": "Dhu al-Qi'dah",
                "ru": "Зуль-Каада",
                "id": "Dzulkaidah",
                "tr": "Zilkade",
                "ur": "ذوالقعدہ",
                "fa": "ذوالقعده",
                "de": "Dhu al-Qi'dah"
            ],
            "hijri_dhul_hijjah": [
                "ar": "ذو الحجة",
                "en": "Dhu al-Hijjah",
                "ru": "Зуль-Хиджа",
                "id": "Dzulhijjah",
                "tr": "Zilhicce",
                "ur": "ذوالحجہ",
                "fa": "ذوالحجه",
                "de": "Dhu al-Hijjah"
            ],
            "hijri_suffix": [
                "ar": "هـ",
                "en": "AH",
                "ru": "г.х.",
                "id": "H",
                "tr": "H",
                "ur": "ھ",
                "fa": "ه‍.ق",
                "de": "n.H."
            ],
            "hijri_year_label": [
                "ar": "عام",
                "en": "",
                "ru": "",
                "id": "",
                "tr": "",
                "ur": "",
                "fa": "",
                "de": ""
            ],
            "hijri_migration_suffix": [
                "ar": "— من هجرة النبي ﷺ",
                "en": "AH",
                "ru": "г.х.",
                "id": "H",
                "tr": "H",
                "ur": "ھ",
                "fa": "ه‍.ق",
                "de": "n.H."
            ],
            
            "number_format": [
                "ar": "تنسيق الأرقام",
                "en": "Number Format",
                "ru": "Формат цифр",
                "id": "Format Angka",
                "tr": "Sayı Formatı",
                "ur": "نمبر فارمیٹ",
                "fa": "فرمت اعداد",
                "de": "Zahlenformat"
            ],
            "numbers_western": [
                "ar": "غربية",
                "en": "Western",
                "ru": "Западные",
                "id": "Barat",
                "tr": "Batı",
                "ur": "مغربی",
                "fa": "غربی",
                "de": "Westlich"
            ],
            "numbers_arabic": [
                "ar": "عربية",
                "en": "Arabic",
                "ru": "Арабские",
                "id": "Arab",
                "tr": "Arapça",
                "ur": "عربی",
                "fa": "عربی",
                "de": "Arabisch"
            ],
            "numbers_persian": [
                "ar": "فارسية",
                "en": "Persian",
                "ru": "Персидские",
                "id": "Persia",
                "tr": "Farsça",
                "ur": "فارسی",
                "fa": "فارسی",
                "de": "Persisch"
            ]
        ]
        
        return translations[key]?[language] ?? translations[key]?["en"] ?? key
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
