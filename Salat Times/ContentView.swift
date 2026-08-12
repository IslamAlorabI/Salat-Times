import SwiftUI
import AppKit

// The menu bar popover.
//
// Shape: a tinted hero carrying the countdown, then a flat list of times, then a toolbar.
// Two things drive that, both from feedback on earlier versions:
//
//  - **No outlined cards.** Every prayer used to sit in its own bordered, translucent
//    rounded rect, and so did the countdown. Eight boxes stacked vertically read as eight
//    buttons rather than a list, and the strokes fought the window's own material. The
//    list is now flat; the only marked row is the next prayer, and it is marked with a
//    leading accent bar and weight rather than a border.
//  - **The hero is what makes it read as an app** rather than a menu. It carries the
//    hour's colour (`PrayerPalette.heroGradient`), so the panel looks different at Fajr
//    than at Maghrib, and it gives the countdown somewhere to be large without competing
//    with the list.
//
// One invariant: **everything time-dependent comes from a single `TimelineView`'s
// `context.date`.** The countdown was once driven by the timeline while the row highlight
// read a bare `Date()` from the body, so the highlight only moved when something else
// invalidated the view — after a prayer passed, the two named different prayers.

struct ContentView: View {
    @EnvironmentObject var manager: PrayerManager
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("numberFormat") private var numberFormat = "western"
    @AppStorage("listMaterial") private var listMaterial = PopoverMaterial.subtle.rawValue
    @AppStorage("showNightTimes") private var showNightTimes = true

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let upcoming = PrayerScheduleCalculator.next(after: context.date, in: manager.events)

                VStack(spacing: 0) {
                    hero(now: context.date, upcoming: upcoming)

                    if let error = manager.errorMessage, manager.timetable.days.isEmpty {
                        errorState(error)
                    } else if manager.isLoading && manager.timetable.days.isEmpty {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        prayerList(upcoming: upcoming)
                    }
                }
            }

            toolbar
        }
        .frame(width: 320)
        // The hero paints its own gradient, so this only shows behind the list and
        // toolbar. `Off` gives a solid window; the rest let progressively more of the
        // desktop through.
        .background {
            if let material = PopoverMaterial.stored(listMaterial).material {
                Rectangle().fill(material)
            } else {
                Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        .onAppear {
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.contentView?.subviews.contains(where: { $0 is NSHostingView<ContentView> }) ?? false }) {
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.hasShadow = true
                }
            }
        }
    }

    // MARK: - Hero

    private func hero(now: Date, upcoming: PrayerEvent?) -> some View {
        VStack(spacing: 0) {
            // Location and sync, small and quiet, over the gradient.
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text(cityName)
                    .font(.system(size: 11, weight: .medium))

                Spacer(minLength: 8)

                let isFresh = manager.lastUpdatedFromServer != nil && !manager.isServingStaleData
                Circle()
                    .fill(isFresh ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(Translations.string(isFresh ? "server_synced" : "offline", language: appLanguage))
                    .font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if let upcoming {
                Text(countdownCaption(for: upcoming))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 14)

                CountdownDigits(remaining: Countdown.from(now, to: upcoming),
                                numberFormat: numberFormat,
                                appLanguage: appLanguage)
                    .padding(.top, 4)

                if let progress = PrayerScheduleCalculator.progress(at: now, in: manager.events) {
                    ProgressTrack(progress: progress)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            } else {
                Text("Salat Times")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.vertical, 22)
            }

            // Both calendars on one line, so the hero closes on a single quiet row.
            HStack(spacing: 6) {
                if let hijri = manager.hijriDate {
                    Text(hijriLine(hijri))
                    Text("·").opacity(0.5)
                }
                Text(gregorianDate)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 13)
        }
        .frame(maxWidth: .infinity)
        .background(PrayerPalette.heroGradient(for: upcoming?.key))
        .id(numberFormat)
    }

    // MARK: - List

    private func prayerList(upcoming: PrayerEvent?) -> some View {
        let today = manager.todayEvents
        let prayers = today.filter { !$0.key.isNightMarker }
        // Ordered by `displayOrder`, not by instant: the API files a night's Midnight and
        // Last Third under the day they are listed with, so sorting by time would float
        // them above Fajr.
        let night = showNightTimes
            ? PrayerKey.displayOrder.filter(\.isNightMarker).compactMap { key in today.first { $0.key == key } }
            : []

        return VStack(spacing: 0) {
            ForEach(prayers) { event in
                row(event, isUpcoming: upcoming?.id == event.id)
            }

            if !night.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                ForEach(night) { event in
                    row(event, isUpcoming: false, isSecondary: true)
                }
            }
        }
        .padding(.vertical, 8)
        .id(numberFormat)
    }

    private func row(_ event: PrayerEvent, isUpcoming: Bool, isSecondary: Bool = false) -> some View {
        PrayerRow(name: event.name(language: appLanguage),
                  time: manager.formattedTime(event.date),
                  icon: event.key.systemImageName,
                  color: PrayerPalette.color(for: event.key, scheme: colorScheme),
                  isUpcoming: isUpcoming,
                  isSecondary: isSecondary)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
            Button(Translations.string("retry", language: appLanguage)) {
                manager.loadSavedCity()
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        VStack(spacing: 0) {
            Divider()
            // Spacers do the spreading, so each button's hover highlight can hug its own
            // label instead of being stretched to a third of the bar.
            HStack(spacing: 2) {
                Spacer(minLength: 0)

                ToolbarButton(icon: "gearshape",
                              title: Translations.string("settings", language: appLanguage),
                              tint: .accentColor) { open("settings") }

                Spacer(minLength: 0)

                ToolbarButton(icon: "calendar",
                              title: Translations.string("monthly_schedule", language: appLanguage),
                              tint: .accentColor) { open("schedule") }

                Spacer(minLength: 0)

                ToolbarButton(icon: "power",
                              title: Translations.string("quit", language: appLanguage),
                              tint: .secondary) { NSApplication.shared.terminate(nil) }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
        }
    }

    private func open(_ id: String) {
        openWindow(id: id)
        // `openWindow` on its own leaves the window behind the frontmost app, because the
        // opener is an `LSUIElement` menu bar extra with no activation of its own.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            let title = Translations.string(id == "settings" ? "settings" : "monthly_schedule",
                                            language: appLanguage)
            if let window = NSApplication.shared.windows.first(where: { $0.title == title }) {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    // MARK: - Formatting

    private var cityName: String {
        City.allCases.first { $0.rawValue == manager.city }?.getName(language: appLanguage)
            ?? manager.city
    }

    private func hijriLine(_ hijri: HijriDate) -> String {
        let month = Translations.hijriMonthName(hijri.month.number, language: appLanguage)
        let day = Translations.localizedNumber(hijri.day, numberFormat: numberFormat)
        let year = Translations.localizedNumber(hijri.year, numberFormat: numberFormat)
        return "\(day) \(month) \(year)"
    }

    private var gregorianDate: String {
        let formatter = DateFormatter()
        formatter.timeZone = manager.timetable.timeZone
        formatter.locale = Locale(identifier: Translations.locale(appLanguage))
        formatter.dateFormat = "d MMM yyyy"
        return Translations.localizedNumber(formatter.string(from: Date()), numberFormat: numberFormat)
    }

    /// Reuses the existing `prayer_after_format` string, minus its trailing colon — it
    /// reads as a label in the old boxed layout but as a stray mark centred in the hero.
    private func countdownCaption(for event: PrayerEvent) -> String {
        Translations.string("prayer_after_format", language: appLanguage)
            .replacingOccurrences(of: "%@", with: event.name(language: appLanguage))
            .trimmingCharacters(in: CharacterSet(charactersIn: ": "))
    }
}

// MARK: - Countdown digits

/// `14 : 56` with unit captions, on the hero.
///
/// The hour field appears only when there is an hour left: `00 hr` spent a third of the
/// countdown saying nothing, and being leftmost and the same weight as the rest, it was
/// what the eye landed on first.
struct CountdownDigits: View {
    let remaining: Countdown
    let numberFormat: String
    let appLanguage: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if remaining.hours > 0 {
                unit(remaining.hours, Translations.string("hours_short", language: appLanguage))
                separator
            }
            unit(remaining.minutes, Translations.string("minutes_short", language: appLanguage))
            separator
            unit(remaining.seconds, Translations.string("seconds_short", language: appLanguage))
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(Translations.localizedNumber(String(format: "%02d", value), numberFormat: numberFormat))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Carries an invisible caption so the colon lines up with the digits. As a bare
    /// `Text` in the `HStack` it centred against each unit's whole stack — digits *plus*
    /// caption — which parked it below the digits' centre line.
    private var separator: some View {
        VStack(spacing: 1) {
            Text(":")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
            Text(Translations.string("minutes_short", language: appLanguage))
                .font(.system(size: 9, weight: .medium))
                .opacity(0)
        }
    }
}

/// How far the interval between the last prayer and the next has run.
struct ProgressTrack: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: max(3, geometry.size.width * progress))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Prayer row

struct PrayerRow: View {
    let name: String
    let time: String
    let icon: String
    let color: Color
    let isUpcoming: Bool
    /// Night markers: shown for reference, never the next prayer, so they read a step
    /// quieter than the six rows above them.
    var isSecondary: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // The marker for "next" — a bar, not a border. Always present so the rows
            // stay aligned; transparent for everything but the next prayer.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isUpcoming ? Color.accentColor : .clear)
                .frame(width: 3, height: 18)

            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isUpcoming ? Color.accentColor : color)
                .frame(width: 20)

            Text(name)
                .font(.system(size: isSecondary ? 12 : 14,
                              weight: isUpcoming ? .semibold : .regular))
                .foregroundStyle(isSecondary ? Color.secondary : Color.primary)

            Spacer(minLength: 8)

            Text(time)
                .font(.system(size: isSecondary ? 12 : 14,
                              weight: isUpcoming ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isUpcoming ? Color.accentColor : Color.secondary)
        }
        .padding(.trailing, 16)
        .padding(.leading, 8)
        .padding(.vertical, isSecondary ? 4 : 6)
    }
}

// MARK: - Toolbar button

/// Flat, full-width, and highlights on hover — the footer links had no hit feedback at all.
struct ToolbarButton: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.09) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
