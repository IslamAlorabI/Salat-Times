import WidgetKit
import SwiftUI

// The desktop/Notification Centre widget.
//
// It is a *reader*, deliberately. Everything it shows comes from the App Group container
// the app already maintains — the settings suite and the cached months — so the widget
// makes no network request, holds no state of its own, and cannot disagree with the menu
// bar about when Asr is. `Core/` does the work in both processes.
//
// Two WidgetKit facts shape the whole file:
//  - A widget cannot tick. The system renders a timeline of entries and shows each until
//    the next, so a per-second countdown is impossible to *push*. `Text(_:style: .timer)`
//    is the way out: the system animates it for free, without waking anything.
//  - Timelines are cheap to build and expensive to refresh, so one entry per prayer for
//    the next day is right — the widget then re-renders exactly when the answer changes.

struct PrayerEntry: TimelineEntry {
    let date: Date
    let next: PrayerEvent?
    let today: [PrayerEvent]
    let city: String
    /// The city's zone. `PrayerEvent` holds an absolute instant and nothing else, so the
    /// zone has to travel with the entry or the widget would render times in the Mac's.
    let timeZoneID: String
    let hijri: HijriDate?
    let settings: PrayerSettings
    /// True when there was no cached month to read — the app has never run, or its cache
    /// was cleared. Worth showing honestly rather than rendering an empty grid.
    let needsApp: Bool

    static func placeholder(settings: PrayerSettings = .load()) -> PrayerEntry {
        PrayerEntry(date: Date(), next: nil, today: [], city: settings.cityRaw,
                    timeZoneID: TimeZone.current.identifier,
                    hijri: nil, settings: settings, needsApp: true)
    }
}

struct PrayerTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { .placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(entries(from: Date()).first ?? .placeholder())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let built = entries(from: Date())
        // `.atEnd` rather than a fixed interval: the entries already cover every moment the
        // display changes, and asking for more refreshes than that just spends the budget
        // WidgetKit gives us.
        completion(Timeline(entries: built, policy: .atEnd))
    }

    /// One entry now, then one at each upcoming prayer for the next day.
    private func entries(from now: Date) -> [PrayerEntry] {
        let settings = PrayerSettings.load()
        guard let timetable = Self.cachedTimetable(around: now, settings: settings) else {
            return [.placeholder(settings: settings)]
        }

        let events = PrayerScheduleCalculator.events(around: now, timetable: timetable, settings: settings)
        let calendar = timetable.calendar
        let hijri = PrayerScheduleCalculator.day(containing: now, timetable: timetable)?.hijri

        func entry(at moment: Date) -> PrayerEntry {
            let stamp = DateStamp.format(moment, in: calendar)
            return PrayerEntry(
                date: moment,
                next: PrayerScheduleCalculator.next(after: moment, in: events),
                today: events.filter { $0.dateStamp == stamp && !$0.key.isNightMarker },
                city: settings.cityRaw,
                timeZoneID: timetable.timeZone.identifier,
                hijri: hijri,
                settings: settings,
                needsApp: false)
        }

        let upcoming = events
            .filter { $0.date > now && $0.date < now.addingTimeInterval(24 * 3600) && !$0.key.isNightMarker }
            .map(\.date)

        return [entry(at: now)] + upcoming.map(entry(at:))
    }

    /// Reads the months the app has already cached. The widget never fetches: it has no
    /// network entitlement, and two processes asking Aladhan for the same month would
    /// double the traffic against an API with no SLA and undocumented rate limits.
    private static func cachedTimetable(around now: Date, settings: PrayerSettings) -> PrayerTimetable? {
        let store = MonthCacheStore()
        let calendar = Calendar(identifier: .gregorian)
        // This month and the next, so the last days of a month still see tomorrow.
        let months = [now, now.addingTimeInterval(31 * 24 * 3600)].map { date -> MonthKey in
            let c = calendar.dateComponents([.year, .month], from: date)
            return MonthKey(year: c.year ?? 0, month: c.month ?? 0, settings: settings)
        }

        var merged: PrayerTimetable?
        for key in months {
            guard let cached = store.load(key) else { continue }
            if var current = merged {
                current.days.merge(cached.timetable.days) { existing, _ in existing }
                merged = current
            } else {
                merged = cached.timetable
            }
        }
        return merged
    }
}

// MARK: - Views

struct SalatTimesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: PrayerEntry

    private var language: String { entry.settings.language }

    var body: some View {
        Group {
            if entry.needsApp {
                needsAppView
            } else {
                switch family {
                case .systemMedium: mediumView
                default: smallView
                }
            }
        }
        .environment(\.layoutDirection, Translations.isRTL(language) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(language)))
        .widgetBackground()
    }

    // MARK: Small — the next prayer and how long is left

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.city)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 2)

            if let next = entry.next {
                Text(next.name(language: language))
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(formatted(next.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrayerPalette.color(for: next.key, scheme: colorScheme))

                // The one thing a widget can animate without being woken.
                Text(next.date, style: .timer)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(Translations.string("loading", language: language))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Medium — the next prayer beside the whole day

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.city)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let hijri = entry.hijri {
                    Text("\(Translations.localizedNumber(hijri.day, numberFormat: entry.settings.numberFormat)) "
                         + Translations.hijriMonthName(hijri.month.number, language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let next = entry.next {
                    Text(next.name(language: language))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(formatted(next.date))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrayerPalette.color(for: next.key, scheme: colorScheme))
                    Text(next.date, style: .timer)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                ForEach(entry.today) { event in
                    let isNext = event.id == entry.next?.id
                    HStack(spacing: 6) {
                        Text(event.name(language: language))
                            .font(.system(size: 11, weight: isNext ? .semibold : .regular))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(formatted(event.date))
                            .font(.system(size: 11, weight: isNext ? .semibold : .regular))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isNext ? AnyShapeStyle(PrayerPalette.color(for: event.key, scheme: colorScheme)) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background {
                        if isNext {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(PrayerPalette.color(for: event.key, scheme: colorScheme).opacity(0.14))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var needsAppView: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(Translations.string("app_name", language: language))
                .font(.system(size: 12, weight: .semibold))
            Text(Translations.string("widget_needs_app", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The same clock the popover shows: city zone, the user's 12/24-hour choice, their
    /// numerals. Built per render because a widget renders a handful of times a day.
    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: entry.timeZoneID) ?? .current
        formatter.locale = Locale(identifier: Translations.locale(language))
        formatter.dateFormat = entry.settings.use24Hour ? "HH:mm" : "h:mm a"
        return Translations.localizedNumber(formatter.string(from: date),
                                            numberFormat: entry.settings.numberFormat)
    }
}

/// `containerBackground` is the required way to fill a widget from macOS 14, and does not
/// exist before it. Without the fallback the widget would not build against the app's
/// macOS 13 floor.
private extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            padding()
        }
    }
}

// MARK: - The widget

struct SalatTimesWidget: Widget {
    let kind = "SalatTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            SalatTimesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Translations.string("app_name",
                                                      language: PrayerSettings.load().language))
        .description(Translations.string("about_tagline",
                                         language: PrayerSettings.load().language))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
