# Salat Times

A beautiful macOS menu bar application that displays Islamic prayer times with support for multiple cities, languages, and calculation methods.

## Features

- 🌙 **Menu Bar Integration** - Quick access to prayer times from your menu bar
- 🌍 **78 Global Cities** - Comprehensive coverage across 7 continents:
  - **Africa** (12 cities): Egypt, Algeria, Morocco, Tunisia, South Africa, Nigeria
  - **Asia** (21 cities): Indonesia, Pakistan, India, Bangladesh, Singapore, Malaysia, Japan, South Korea, China, Taiwan, Central Asia, Afghanistan
  - **Australia & Oceania** (6 cities): Australia, New Zealand
  - **Europe** (21 cities): UK, France, Germany, Russia, Netherlands, Italy, Spain, Scandinavia, Turkey, Balkans
  - **Middle East** (17 cities): Saudi Arabia, UAE, Qatar, Kuwait, Bahrain, Oman, Iran, Iraq, Syria, Jordan, Lebanon, Palestine, Yemen
  - **North America** (15 cities): USA, Canada, Mexico
  - **South America** (6 cities): Brazil, Argentina, Peru, Colombia, Chile, Venezuela
- 🔍 **Searchable City Picker** - Quickly find your city with real-time search filtering
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
- 📐 **21 Calculation Methods** - Comprehensive global coverage:
  - University of Karachi (Pakistan)
  - North America (ISNA)
  - Muslim World League
  - Umm Al-Qura (Makkah)
  - Egyptian General Authority
  - University of Tehran (Iran)
  - Gulf Region
  - Kuwait
  - Qatar
  - Singapore (MUIS)
  - France (UOIF)
  - Turkey (Diyanet)
  - Russia
  - Moonsighting Committee
  - Dubai
  - Malaysia (JAKIM)
  - Tunisia
  - Algeria
  - Indonesia (KEMENAG)
  - Morocco
  - Portugal
  - Jordan
- 🤖 **Auto Method Selection** - Calculation method automatically selected based on your city
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
- **Location**: Search and select from 78 cities worldwide, organized by continent
- **Calculation Method**: Automatically selected based on your city, or manually choose from 21 methods
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
- `calculationMethod`: Prayer calculation method (1-23)
- `timeFormat24`: Boolean for 24-hour format preference
- `notification_*_enabled`: Per-prayer notification toggles
- `notification_*_sound`: Custom sound selections per prayer

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

Current version: **3.0**

## Author

Made with ♥︎ by Islam AlorabI - 2026

## License

This project is licensed under the MIT License - see below for details:

```
MIT License

Copyright (c) 2026 Islam AlorabI

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, feature requests, or questions, please open an issue on the repository.

---

**Note**: This app runs as a menu bar application (LSUIElement) and won't appear in the Dock. To quit the app, right-click the menu bar icon and select "Quit" or use ⌘Q when the app window is focused.
