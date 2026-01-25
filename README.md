# Salat Times

Salat Times is a native macOS menu bar application designed to display accurate Islamic prayer times. It combines precise astronomical calculations with a modern, unobtrusive user interface, offering extensive customization options for global locations, calculation methods, and notification preferences.

## Features

- **Onboarding Experience**: First-launch Welcome Screen that guides users through initial setup:
  - App introduction with icon and description
  - Language selection
  - Location and calculation method configuration
  - Time format and notification preferences
  - Launch at login option
- **Menu Bar Integration**: Persistent access to prayer times directly from the macOS menu bar, featuring a dynamic countdown to the next prayer.
- **Global Location Support**: Comprehensive coverage for 78 major cities across Africa, Asia, Australia, Europe, the Middle East, North America, and South America.
- **Precise Calculations**: Includes 21 distinct calculation methods to ensure accuracy according to local conventions (e.g., ISNA, Muslim World League, Umm Al-Qura).
- **Auto-Location**: Intelligent automatic method selection based on the user's geographical location.
- **Advanced Notifications**:
  - Individual toggle controls for Fajr, Dhuhr, Asr, Maghrib, and Isha.
  - Custom sound selection including Glass, Ping, Hero, Submarine, Purr, Basso, Blow, Funk, and Sosumi.
  - Support for system default sounds.
- **Multilingual Interface**: Complete localization for 8 languages:
  - English
  - Arabic (with RTL support)
  - Russian
  - Indonesian
  - Turkish
  - Urdu (with RTL support)
  - Persian (with RTL support)
  - German
- **Flexible Time Formats**: Support for both 12-hour and 24-hour time display.
- **Modern UI/UX**: Designed with native SwiftUI components, featuring adaptive light/dark mode support and translucent material effects.

## System Requirements

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later (for development)

## Technical Stack

- **Language**: Swift 5.7+
- **Frameworks**: SwiftUI, AppKit, CoreLocation, UserNotifications, Combine
- **Architecture**: MVVM (Model-View-ViewModel)
- **External API**: Aladhan Prayer Times API for astronomical data

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd "Salat Times"
   ```

2. Open the project in Xcode:
   ```bash
   open "Salat Times.xcodeproj"
   ```

3. Build and Run:
   - Select your target scheme and device.
   - Press `Cmd + R` to build and launch the application.

## Configuration

The application persists user preferences using `UserDefaults`. Key configuration parameters include:

- `appLanguage`: Interface language code (e.g., "en", "ar").
- `selectedCityRaw`: Identifier for the currently selected city.
- `calculationMethod`: Integer representing the selected calculation method.
- `timeFormat24`: Boolean flag for time format preference.
- `hasShownWelcome`: Boolean flag tracking first-launch onboarding completion.
- `notification_*_enabled`: Boolean flags for individual prayer notifications.
- `notification_*_sound`: String identifiers for selected notification sounds.

## License

This project is licensed under the MIT License.

Copyright (c) 2026 Islam AlorabI

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
