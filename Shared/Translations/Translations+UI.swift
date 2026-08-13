import Foundation

// App chrome, language names, general settings and the welcome screen.
nonisolated let uiStrings: [String: [String: String]] = [
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
        "ar": "تحديث أوقات الصلاة",
        "en": "Refresh Prayer Times",
        "ru": "Обновить время молитв",
        "id": "Muat Ulang Waktu Sholat",
        "tr": "Namaz Vakitlerini Yenile",
        "ur": "نماز کے اوقات تازہ کریں",
        "fa": "به‌روزرسانی اوقات نماز",
        "de": "Gebetszeiten aktualisieren"
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
    "refresh": [
        "ar": "تحديث",
        "en": "Refresh",
        "ru": "Обновить",
        "id": "Muat Ulang",
        "tr": "Yenile",
        "ur": "تازہ کریں",
        "fa": "به‌روزرسانی",
        "de": "Aktualisieren"
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
    "widget_needs_app": [
        "ar": "افتح التطبيق لتحميل المواقيت",
        "en": "Open the app to load times",
        "ru": "Откройте приложение, чтобы загрузить время",
        "id": "Buka aplikasi untuk memuat waktu",
        "tr": "Vakitleri yüklemek için uygulamayı açın",
        "ur": "اوقات لوڈ کرنے کے لیے ایپ کھولیں",
        "fa": "برای بارگذاری اوقات، برنامه را باز کنید",
        "de": "Öffne die App, um die Zeiten zu laden"
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
    "updated": [
        "ar": "محدث",
        "en": "Updated",
        "ru": "Обновлено",
        "id": "Diperbarui",
        "tr": "Güncellendi",
        "ur": "اپ ڈیٹ",
        "fa": "به‌روز",
        "de": "Aktualisiert"
    ],
    "server_synced": [
        "ar": "السيرفر محدث",
        "en": "Server Updated",
        "ru": "Сервер обновлен",
        "id": "Server Diperbarui",
        "tr": "Sunucu Güncellendi",
        "ur": "سرور اپ ڈیٹ",
        "fa": "سرور به‌روز",
        "de": "Server Aktualisiert"
    ],
    "offline": [
        "ar": "غير متصل",
        "en": "Offline",
        "ru": "Не в сети",
        "id": "Offline",
        "tr": "Çevrimdışı",
        "ur": "آف لائن",
        "fa": "آفلاین",
        "de": "Offline"
    ],
    "prayer_after_format": [
        "ar": "صلاة %@ بعد:",
        "en": "%@ prayer in:",
        "ru": "Молитва %@ через:",
        "id": "Sholat %@ dalam:",
        "tr": "%@ namazına:",
        "ur": "%@ نماز بعد:",
        "fa": "نماز %@ بعد از:",
        "de": "%@ Gebet in:"
    ],
    "hours_short": [
        "ar": "ساعة",
        "en": "hr",
        "ru": "ч",
        "id": "jam",
        "tr": "sa",
        "ur": "گھنٹہ",
        "fa": "ساعت",
        "de": "Std"
    ],
    "minutes_short": [
        "ar": "دقيقة",
        "en": "min",
        "ru": "мин",
        "id": "mnt",
        "tr": "dk",
        "ur": "منٹ",
        "fa": "دقیقه",
        "de": "Min"
    ],
    "seconds_short": [
        "ar": "ثانية",
        "en": "sec",
        "ru": "сек",
        "id": "dtk",
        "tr": "sn",
        "ur": "سیکنڈ",
        "fa": "ثانیه",
        "de": "Sek"
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

    // Monthly schedule window.
    "monthly_schedule": [
        "ar": "جدول الشهر",
        "en": "Monthly Schedule",
        "ru": "Расписание на месяц",
        "id": "Jadwal Bulanan",
        "tr": "Aylık Takvim",
        "ur": "ماہانہ شیڈول",
        "fa": "برنامه ماهانه",
        "de": "Monatsplan"
    ],
    "previous_month": [
        "ar": "الشهر السابق",
        "en": "Previous month",
        "ru": "Предыдущий месяц",
        "id": "Bulan sebelumnya",
        "tr": "Önceki ay",
        "ur": "پچھلا مہینہ",
        "fa": "ماه قبل",
        "de": "Vorheriger Monat"
    ],
    "next_month": [
        "ar": "الشهر التالي",
        "en": "Next month",
        "ru": "Следующий месяц",
        "id": "Bulan berikutnya",
        "tr": "Sonraki ay",
        "ur": "اگلا مہینہ",
        "fa": "ماه بعد",
        "de": "Nächster Monat"
    ],
    "today": [
        "ar": "اليوم",
        "en": "Today",
        "ru": "Сегодня",
        "id": "Hari ini",
        "tr": "Bugün",
        "ur": "آج",
        "fa": "امروز",
        "de": "Heute"
    ],
    "schedule_date": [
        "ar": "التاريخ",
        "en": "Date",
        "ru": "Дата",
        "id": "Tanggal",
        "tr": "Tarih",
        "ur": "تاریخ",
        "fa": "تاریخ",
        "de": "Datum"
    ],
    "export": [
        "ar": "تصدير",
        "en": "Export",
        "ru": "Экспорт",
        "id": "Ekspor",
        "tr": "Dışa aktar",
        "ur": "برآمد",
        "fa": "خروجی",
        "de": "Exportieren"
    ],
    "export_csv": [
        "ar": "جدول بيانات (CSV)",
        "en": "Spreadsheet (CSV)",
        "ru": "Таблица (CSV)",
        "id": "Lembar sebar (CSV)",
        "tr": "Hesap tablosu (CSV)",
        "ur": "اسپریڈ شیٹ (CSV)",
        "fa": "صفحه‌گسترده (CSV)",
        "de": "Tabelle (CSV)"
    ],
    "export_pdf": [
        "ar": "ملف PDF (A4)",
        "en": "PDF document (A4)",
        "ru": "Документ PDF (A4)",
        "id": "Dokumen PDF (A4)",
        "tr": "PDF belgesi (A4)",
        "ur": "PDF دستاویز (A4)",
        "fa": "سند PDF (A4)",
        "de": "PDF-Dokument (A4)"
    ],
    "export_png": [
        "ar": "صورة PNG (A4)",
        "en": "PNG image (A4)",
        "ru": "Изображение PNG (A4)",
        "id": "Gambar PNG (A4)",
        "tr": "PNG görüntüsü (A4)",
        "ur": "PNG تصویر (A4)",
        "fa": "تصویر PNG (A4)",
        "de": "PNG-Bild (A4)"
    ],
    "print": [
        "ar": "طباعة",
        "en": "Print",
        "ru": "Печать",
        "id": "Cetak",
        "tr": "Yazdır",
        "ur": "پرنٹ",
        "fa": "چاپ",
        "de": "Drucken"
    ],
    "schedule_footnote": [
        "ar": "الأوقات تعكس إعداداتك الحالية.",
        "en": "Times reflect your current settings.",
        "ru": "Время показано с учётом ваших настроек.",
        "id": "Waktu mengikuti pengaturan Anda saat ini.",
        "tr": "Vakitler mevcut ayarlarınızı yansıtır.",
        "ur": "اوقات آپ کی موجودہ ترتیبات کے مطابق ہیں۔",
        "fa": "اوقات بر اساس تنظیمات فعلی شماست.",
        "de": "Die Zeiten folgen Ihren aktuellen Einstellungen."
    ],
]

