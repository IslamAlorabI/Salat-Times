import WidgetKit
import SwiftUI

// WidgetKit glue: read the App Group, build snapshots, hand them to the views in
// `WidgetViews.swift` — which know nothing about WidgetKit and can therefore be rendered
// and inspected off-screen while being designed.
//
// The widget is a *reader*. Everything comes from the container the app already maintains,
// so it makes no network request and cannot disagree with the menu bar about when Asr is.

struct PrayerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct PrayerTimelineProvider: TimelineProvider {
    /// How often an entry is emitted inside a prayer period.
    ///
    /// This is not a refresh rate and costs no budget: WidgetKit's reload allowance is
    /// spent on *timelines*, not on the entries inside one. Emitting a frame every ten
    /// minutes is what makes the ring visibly advance rather than jump once per prayer.
    private static let ringStep: TimeInterval = 10 * 60

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), snapshot: .empty())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(entries(from: Date()).first ?? PrayerEntry(date: Date(), snapshot: .empty()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        completion(Timeline(entries: entries(from: Date()), policy: .atEnd))
    }

    private func entries(from now: Date) -> [PrayerEntry] {
        let settings = PrayerSettings.load(from: SharedStore.currentDefaults())
        guard let timetable = Self.cachedTimetable(around: now, settings: settings) else {
            return [PrayerEntry(date: now,
                                snapshot: .empty(language: settings.language,
                                                 numberFormat: settings.numberFormat))]
        }

        let events = PrayerScheduleCalculator.events(around: now, timetable: timetable, settings: settings)
        let builder = SnapshotBuilder(timetable: timetable, settings: settings, events: events)

        // Every prayer for the next day, plus a frame every ten minutes so the ring moves.
        var moments: Set<Date> = [now]
        for event in events where event.date > now && event.date < now.addingTimeInterval(24 * 3600) {
            moments.insert(event.date)
        }
        var tick = now
        let horizon = now.addingTimeInterval(24 * 3600)
        while tick < horizon {
            tick = tick.addingTimeInterval(Self.ringStep)
            moments.insert(tick)
        }

        return moments.sorted().map { PrayerEntry(date: $0, snapshot: builder.snapshot(at: $0)) }
    }

    /// Reads the months the app has already cached. The widget never fetches: it has no
    /// network entitlement, and two processes asking an API with no SLA for the same month
    /// is exactly the traffic month-granularity caching exists to avoid.
    private static func cachedTimetable(around now: Date, settings: PrayerSettings) -> PrayerTimetable? {
        let store = MonthCacheStore()
        let calendar = Calendar(identifier: .gregorian)
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

/// Turns the shared model into finished display values.
///
/// A class with caches, not a struct, and for a measured reason: a timeline holds ~150
/// entries (a frame every ten minutes so the ring moves) and each one wanted six formatted
/// clock strings. Building a `DateFormatter` per string meant ~900 allocations per timeline
/// — the same mistake that made the monthly schedule crawl, except here it is spent inside
/// WidgetKit's budget for producing a timeline at all, which is why the widgets sat on
/// their loading skeletons.
///
/// The rows for a given civil day are identical across every entry *except* for which one
/// is next and which have passed, so they are formatted once per day and the flags applied
/// per entry.
private final class SnapshotBuilder {
    private struct RowTemplate {
        let id: String
        let name: String
        let time: String
        let key: PrayerKey
        let date: Date
    }

    let timetable: PrayerTimetable
    let settings: PrayerSettings
    let events: [PrayerEvent]

    private let formatter: DateFormatter
    private let cityName: String
    private var rowsByDay: [String: [RowTemplate]] = [:]
    private var hijriByDay: [String: String?] = [:]

    init(timetable: PrayerTimetable, settings: PrayerSettings, events: [PrayerEvent]) {
        self.timetable = timetable
        self.settings = settings
        self.events = events

        let formatter = DateFormatter()
        formatter.timeZone = timetable.timeZone
        formatter.locale = Locale(identifier: Translations.locale(settings.language))
        formatter.dateFormat = settings.use24Hour ? "HH:mm" : "h:mm a"
        self.formatter = formatter

        // The stored value is the `City` enum's English raw value, which is not what an
        // Arabic reader sees anywhere else in the app. A detected location's name is
        // already localized by the geocoder, so it falls through unchanged.
        self.cityName = City.allCases.first { $0.rawValue == settings.cityRaw }?
            .getName(language: settings.language) ?? settings.cityRaw
    }

    func snapshot(at moment: Date) -> WidgetSnapshot {
        let stamp = DateStamp.format(moment, in: timetable.calendar)
        let next = PrayerScheduleCalculator.next(after: moment, in: events)
        let current = PrayerScheduleCalculator.current(at: moment, in: events)

        let rows = templates(for: stamp).map { template in
            WidgetSnapshot.Row(id: template.id,
                               name: template.name,
                               time: template.time,
                               key: template.key,
                               isNext: template.id == next?.id,
                               isPast: template.date <= moment)
        }

        return WidgetSnapshot(
            city: cityName,
            hijri: hijri(for: stamp),
            nextName: next?.name(language: settings.language),
            nextTime: next.map { formatted($0.date) },
            nextKey: next?.key,
            nextDate: next?.date,
            progress: progress(at: moment, from: current, to: next),
            rows: rows,
            language: settings.language,
            numberFormat: settings.numberFormat,
            localeIdentifier: WidgetSnapshot.locale(language: settings.language,
                                                    numberFormat: settings.numberFormat),
            needsApp: false)
    }

    private func templates(for stamp: String) -> [RowTemplate] {
        if let cached = rowsByDay[stamp] { return cached }
        let built = events
            .filter { $0.dateStamp == stamp && !$0.key.isNightMarker }
            .map { RowTemplate(id: $0.id,
                               name: $0.name(language: settings.language),
                               time: formatted($0.date),
                               key: $0.key,
                               date: $0.date) }
        rowsByDay[stamp] = built
        return built
    }

    /// How much of the current prayer period has elapsed. Before the day's first prayer
    /// this measures from yesterday's Isha, which the rolling event window provides.
    private func progress(at moment: Date, from current: PrayerEvent?, to next: PrayerEvent?) -> Double {
        guard let current, let next else { return 0 }
        let span = next.date.timeIntervalSince(current.date)
        guard span > 0 else { return 0 }
        return min(max(moment.timeIntervalSince(current.date) / span, 0), 1)
    }

    private func hijri(for stamp: String) -> String? {
        if let cached = hijriByDay[stamp] { return cached }
        let value: String?
        if let hijri = timetable.days[stamp]?.hijri {
            let day = Translations.localizedNumber(hijri.day, numberFormat: settings.numberFormat)
            value = "\(day) \(Translations.hijriMonthName(hijri.month.number, language: settings.language))"
        } else {
            value = nil
        }
        hijriByDay[stamp] = value
        return value
    }

    private func formatted(_ date: Date) -> String {
        Translations.localizedNumber(formatter.string(from: date), numberFormat: settings.numberFormat)
    }
}

// MARK: - The widgets

private func widgetLanguage() -> String {
    PrayerSettings.load(from: SharedStore.currentDefaults()).language
}

/// The next prayer as a ring: which one, when, how long, and how much of the period is
/// gone — the last of which is the part a line of text cannot say.
struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatTimesNextPrayer", provider: PrayerTimelineProvider()) { entry in
            FamilyResolvingView { size in
                NextPrayerWidgetView(snapshot: entry.snapshot, size: size)
            }
            .widgetContainerBackground()
        }
        .configurationDisplayName(Translations.string("widget_next_prayer", language: widgetLanguage()))
        .description(Translations.string("widget_next_prayer_hint", language: widgetLanguage()))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// The whole day at a glance, with the next prayer marked.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SalatTimesToday", provider: PrayerTimelineProvider()) { entry in
            FamilyResolvingView { size in
                TodayWidgetView(snapshot: entry.snapshot, size: size)
            }
            .widgetContainerBackground()
        }
        .configurationDisplayName(Translations.string("widget_today", language: widgetLanguage()))
        .description(Translations.string("widget_today_hint", language: widgetLanguage()))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension View {
    /// **Mandatory from macOS 14.** A widget that does not declare a container background
    /// is not merely unstyled — the system refuses to draw it at all and substitutes
    /// "Please adopt containerBackground API" in its place, which looks exactly like the
    /// widget crashing.
    ///
    /// It lives here rather than in `WidgetViews.swift` because the `.widget` placement
    /// comes from WidgetKit, and those views are deliberately WidgetKit-free so they can be
    /// rendered off-screen while being designed. The trade-off is that it must be applied
    /// at every widget's entry view — there is no shared root to hang it on.
    @ViewBuilder
    func widgetContainerBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            self
        }
    }
}

/// The views take a plain `WidgetSize` so they can be rendered outside WidgetKit. This is
/// the only place the two vocabularies meet.
private struct FamilyResolvingView<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let content: (WidgetSize) -> Content

    var body: some View {
        content(family == .systemMedium ? .medium : .small)
    }
}
