import SwiftUI

/// How much of the desktop shows through the popover's list.
///
/// The original design gave the window *and* every prayer row its own
/// `.ultraThinMaterial`, which is the most transparent material there is — stacked, it
/// left the list washed out and hard to read against a busy desktop. These levels run the
/// other way: `subtle` is nearly opaque and is the default, and you opt *into* seeing
/// more through it.
enum PopoverMaterial: Int, CaseIterable, Identifiable {
    case off = 0
    case subtle = 1
    case medium = 2
    case full = 3

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .off:    return "translucency_off"
        case .subtle: return "translucency_subtle"
        case .medium: return "translucency_medium"
        case .full:   return "translucency_full"
        }
    }

    var material: Material? {
        switch self {
        case .off:    return nil            // a solid window background instead
        case .subtle: return .ultraThickMaterial
        case .medium: return .thickMaterial
        case .full:   return .regularMaterial
        }
    }

    static func stored(_ raw: Int) -> PopoverMaterial {
        PopoverMaterial(rawValue: raw) ?? .subtle
    }
}

/// Per-prayer colour, roughly following the sky at that hour.
///
/// Lives in the app target rather than on `PrayerKey`, because `Core/` must not import
/// SwiftUI — the behaviour checks compile it with plain `swiftc`, and a widget target
/// would too.
enum PrayerPalette {
    /// The accent used for a prayer's icon in the list.
    static func color(for key: PrayerKey, scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch key {
        case .fajr:
            return dark ? Color(red: 0.60, green: 0.50, blue: 1.00) : Color(red: 0.40, green: 0.30, blue: 0.70)
        case .sunrise:
            return dark ? Color(red: 1.00, green: 0.70, blue: 0.40) : Color(red: 0.80, green: 0.40, blue: 0.00)
        case .dhuhr:
            return dark ? Color(red: 1.00, green: 0.90, blue: 0.40) : Color(red: 0.80, green: 0.60, blue: 0.00)
        case .asr:
            return dark ? Color(red: 1.00, green: 0.60, blue: 0.20) : Color(red: 0.90, green: 0.40, blue: 0.00)
        case .maghrib:
            return dark ? Color(red: 1.00, green: 0.40, blue: 0.30) : Color(red: 0.80, green: 0.20, blue: 0.10)
        case .isha:
            return dark ? Color(red: 0.40, green: 0.60, blue: 1.00) : Color(red: 0.10, green: 0.30, blue: 0.70)
        case .midnight, .lastThird:
            return dark ? Color(red: 0.55, green: 0.55, blue: 0.85) : Color(red: 0.35, green: 0.35, blue: 0.60)
        }
    }

    /// The hero's background: the hour's hue, but always dark.
    ///
    /// Deliberately *not* the list colour above. These are fixed dark stops rather than
    /// the palette hue at full brightness, so that white text stays readable for every
    /// prayer in both appearances — a Dhuhr hero in the list's yellow would be white on
    /// gold, which is unreadable in either mode.
    static func heroGradient(for key: PrayerKey?) -> LinearGradient {
        let stops: (Color, Color)
        switch key {
        case .fajr:
            stops = (Color(red: 0.17, green: 0.11, blue: 0.33), Color(red: 0.29, green: 0.19, blue: 0.50))
        case .sunrise:
            stops = (Color(red: 0.36, green: 0.19, blue: 0.10), Color(red: 0.58, green: 0.33, blue: 0.13))
        case .dhuhr:
            stops = (Color(red: 0.34, green: 0.27, blue: 0.06), Color(red: 0.56, green: 0.44, blue: 0.09))
        case .asr:
            stops = (Color(red: 0.37, green: 0.20, blue: 0.07), Color(red: 0.62, green: 0.34, blue: 0.09))
        case .maghrib:
            stops = (Color(red: 0.36, green: 0.12, blue: 0.09), Color(red: 0.60, green: 0.20, blue: 0.13))
        case .isha:
            stops = (Color(red: 0.07, green: 0.13, blue: 0.29), Color(red: 0.12, green: 0.23, blue: 0.46))
        case .midnight, .lastThird:
            stops = (Color(red: 0.10, green: 0.10, blue: 0.18), Color(red: 0.16, green: 0.16, blue: 0.27))
        case nil:
            stops = (Color(red: 0.13, green: 0.14, blue: 0.20), Color(red: 0.20, green: 0.22, blue: 0.30))
        }
        return LinearGradient(colors: [stops.0, stops.1],
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
    }
}
