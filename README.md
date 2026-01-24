# Salat Times

A beautiful macOS menu bar application that displays Islamic prayer times with support for multiple cities, languages, and calculation methods.

## Features

- 🌙 **Menu Bar Integration** - Quick access to prayer times from your menu bar
- 🌍 **Multiple Cities** - Support for Cairo, Riyadh, New York, Kafr El-Sheikh, and Algiers
- 🌐 **Multi-Language Support** - Full support for 8 languages:
  - Arabic (العربية) with RTL layout
  - English
  - Russian (Русский)
  - Indonesian (Indonesia)
  - Turkish (Türkçe)
  - Urdu (اردو) with RTL layout
  - Persian (فارسی) with RTL layout
  - German (Deutsch)
- ⏰ **Flexible Time Format** - Choose between 12-hour and 24-hour time formats
- 📐 **Multiple Calculation Methods**:
  - Egyptian General Authority
  - Umm Al-Qura (Makkah)
  - Muslim World League
  - North America (ISNA)
- 🔔 **Prayer Notifications** - Customizable notifications for each prayer with:
  - Individual enable/disable toggles per prayer
  - Custom notification sounds (Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi, Submarine, Tink)
  - Sound preview functionality
  - Default system sound option
- ✨ **Beautiful UI** - Modern, translucent design with visual highlights for upcoming prayers
- 🎨 **Custom App Icons** - Multiple icon variants (Default, Dark, Tinted Light)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later
- Swift 5.7 or later

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd "Salat Times"
```

2. Open the project in Xcode:
```bash
open "Salat Times.xcodeproj"
```

3. Build and run the project (⌘R)

## Usage

### Accessing Prayer Times

1. Launch the app - it will appear in your menu bar with a moon and stars icon (🌙⭐)
2. Click the menu bar icon to view today's prayer times
3. The upcoming prayer will be highlighted in blue

### Settings

Click the "Settings" button to access:

- **Language**: Choose from 8 supported languages (Arabic, English, Russian, Indonesian, Turkish, Urdu, Persian, German)
- **Location**: Select your city from the available options
- **Calculation Method**: Choose your preferred prayer time calculation method
- **Time Format**: Toggle between 12-hour and 24-hour formats
- **Prayer Notifications**: Customize notifications for each prayer:
  - Enable/disable notifications per prayer (Fajr, Dhuhr, Asr, Maghrib, Isha)
  - Select custom notification sounds for each prayer
  - Preview sounds before applying

### Prayer Times Displayed

- **Fajr** (الفجر) - Dawn prayer
- **Sunrise** (الشروق) - Sunrise
- **Dhuhr** (الظهر) - Noon prayer
- **Asr** (العصر) - Afternoon prayer
- **Maghrib** (المغرب) - Sunset prayer
- **Isha** (العشاء) - Night prayer

## API

This app uses the [Aladhan API](https://aladhan.com/prayer-times-api) to fetch accurate prayer times based on location coordinates and calculation methods.

## Project Structure

```
Salat Times/
├── SalatTimesApp.swift      # Main app entry point
├── ContentView.swift        # Main menu bar view
├── SettingsView.swift       # Settings window with modular components
├── PrayerManager.swift      # Core logic for prayer times and notifications
├── Translations.swift       # Multi-language translation system
├── Assets.xcassets/         # App icons and assets
└── *.gpx                    # Location files for testing
```

## Configuration

The app stores user preferences using `UserDefaults`:
- `appLanguage`: Language code ("ar", "en", "ru", "id", "tr", "ur", "fa", "de")
- `selectedCityRaw`: Selected city identifier
- `calculationMethod`: Prayer calculation method (2, 3, 4, or 5)
- `timeFormat24`: Boolean for 24-hour format preference
- `fajrNotificationEnabled`, `dhuhrNotificationEnabled`, etc.: Per-prayer notification toggles
- `fajrNotificationSound`, `dhuhrNotificationSound`, etc.: Custom sound selections per prayer

## Permissions

The app requires:
- **Location Services**: To determine your location (optional, can use preset cities)
- **Notifications**: To send prayer time reminders

## Development

### Building from Source

1. Ensure you have Xcode installed
2. Open `Salat Times.xcodeproj`
3. Select your target device/simulator
4. Build and run (⌘R)

### Dependencies

- SwiftUI (for UI)
- AppKit (for macOS integration)
- CoreLocation (for location services)
- UserNotifications (for prayer reminders)

## Version

Current version: **2.0**

## Author

Made with ♥︎ by Islam Alorabi - 2026

## License

[Add your license here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, feature requests, or questions, please open an issue on the repository.

---

**Note**: This app runs as a menu bar application (LSUIElement) and won't appear in the Dock. To quit the app, right-click the menu bar icon and select "Quit" or use ⌘Q when the app window is focused.
