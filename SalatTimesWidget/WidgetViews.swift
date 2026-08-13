import SwiftUI

// The widget's looks, deliberately free of WidgetKit.
//
// Nothing here knows what a timeline or a `widgetFamily` is: a view takes a finished
// `WidgetSnapshot` and a size, and draws it. That is what lets the layouts be rendered
// off-screen at exact widget dimensions and *looked at* while designing them, instead of
// rebuilding, reinstalling and squinting at the desktop each time.

/// Everything a widget draws, already resolved — localized city name, formatted clock
/// strings, the progress fraction. The provider does the work; the views only lay out.
struct WidgetSnapshot {
    struct Row: Identifiable {
        let id: String
        let name: String
        let time: String
        let key: PrayerKey
        let isNext: Bool
        let isPast: Bool
    }

    var city: String
    var hijri: String?
    var nextName: String?
    var nextTime: String?
    var nextKey: PrayerKey?
    /// The real instant, kept because the countdown is the one thing the system animates
    /// for us — and it needs a `Date`, not a string.
    var nextDate: Date?
    /// How far through the current prayer period we are, 0...1.
    var progress: Double
    var rows: [Row]
    var language: String
    var numberFormat: String
    /// Language *and* numbering system. The countdown is drawn by the system, so it cannot
    /// be run through `Translations.localizedNumber` — the locale is the only lever, and
    /// plain `ar` renders western digits next to Arabic-Indic prayer times.
    var localeIdentifier: String
    var needsApp: Bool

    var isRTL: Bool { Translations.isRTL(language) }

    static func empty(language: String = "ar", numberFormat: String = "western") -> WidgetSnapshot {
        WidgetSnapshot(city: "", hijri: nil, nextName: nil, nextTime: nil, nextKey: nil,
                       nextDate: nil, progress: 0, rows: [], language: language,
                       numberFormat: numberFormat,
                       localeIdentifier: WidgetSnapshot.locale(language: language, numberFormat: numberFormat),
                       needsApp: true)
    }

    /// `western` → `latn`, `arabic` → `arab`, `persian` → `arabext`, which are the ICU
    /// numbering-system names for the three the app offers.
    static func locale(language: String, numberFormat: String) -> String {
        switch numberFormat {
        case "arabic": return "\(language)@numbers=arab"
        case "persian": return "\(language)@numbers=arabext"
        default: return "\(language)@numbers=latn"
        }
    }
}

enum WidgetSize {
    case small
    case medium
}

// MARK: - Next prayer, as a ring

/// The ring is the point of this one: at a glance it says both *which* prayer is next and
/// *how much of the period is gone*, which a line of text cannot. The countdown sits in the
/// middle because that is where the eye lands.
struct NextPrayerWidgetView: View {
    let snapshot: WidgetSnapshot
    let size: WidgetSize
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        guard let key = snapshot.nextKey else { return .accentColor }
        return PrayerPalette.color(for: key, scheme: colorScheme)
    }

    var body: some View {
        Group {
            if snapshot.needsApp {
                WidgetPlaceholder(language: snapshot.language)
            } else if size == .small {
                small
            } else {
                medium
            }
        }
        .widgetLocalized(snapshot)
    }

    private var small: some View {
        VStack(spacing: 6) {
            header
            ring(diameter: 96)
            Spacer(minLength: 0)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                header
                ring(diameter: 88)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            DayListView(snapshot: snapshot, compact: true)
                .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: 1) {
            Text(snapshot.city)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let hijri = snapshot.hijri {
                Text(hijri)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.secondary)
    }

    private func ring(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.001, min(snapshot.progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                // From the top, clockwise, like every progress ring on the system.
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(snapshot.nextName ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let date = snapshot.nextDate {
                    // The only thing a widget can animate without being woken.
                    Text(date, style: .timer)
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(tint)
                        // A timer counting up to six hours is wider than one counting
                        // minutes; without a fixed box the ring's contents jump about.
                        .frame(width: diameter - 26)
                }

                Text(snapshot.nextTime ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - The whole day

struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot
    let size: WidgetSize

    var body: some View {
        Group {
            if snapshot.needsApp {
                WidgetPlaceholder(language: snapshot.language)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(snapshot.city)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if let hijri = snapshot.hijri {
                            Text(hijri)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if size == .medium {
                        // A medium widget is twice as wide as a small one but exactly as
                        // tall, so six stacked rows do not fit — they clipped the header
                        // and Isha. Two columns of three use the width that is actually
                        // there.
                        HStack(alignment: .top, spacing: 16) {
                            DayListView(snapshot: snapshot, compact: false,
                                        rows: Array(snapshot.rows.prefix(3)))
                            DayListView(snapshot: snapshot, compact: false,
                                        rows: Array(snapshot.rows.dropFirst(3)))
                        }
                    } else {
                        DayListView(snapshot: snapshot, compact: true)
                    }

                    Spacer(minLength: 0)

                    if size == .medium, let date = snapshot.nextDate {
                        CountdownFooter(snapshot: snapshot, date: date)
                    }
                }
            }
        }
        .widgetLocalized(snapshot)
    }
}

/// Today's prayers, one per line. The next one is filled rather than merely coloured —
/// colour alone is not enough to find at a glance on a busy desktop wallpaper.
struct DayListView: View {
    let snapshot: WidgetSnapshot
    var compact: Bool
    /// A slice, when the layout splits the day across columns. Defaults to the whole day.
    var rows: [WidgetSnapshot.Row]? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: compact ? 1 : 3) {
            ForEach(rows ?? snapshot.rows) { row in
                let tint = PrayerPalette.color(for: row.key, scheme: colorScheme)
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: compact ? 11 : 12, weight: row.isNext ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(row.time)
                        .font(.system(size: compact ? 11 : 12, weight: row.isNext ? .semibold : .regular))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .foregroundStyle(row.isNext ? AnyShapeStyle(tint)
                                 : AnyShapeStyle(row.isPast ? .tertiary : .secondary))
                .padding(.horizontal, 6)
                .padding(.vertical, compact ? 2 : 3)
                .background {
                    if row.isNext {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tint.opacity(0.16))
                    }
                }
            }
        }
    }
}

/// The next prayer and a live countdown, on one line. Cheap in space and the single most
/// useful thing the day list does not already say.
struct CountdownFooter: View {
    let snapshot: WidgetSnapshot
    let date: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .semibold))
            Text(snapshot.nextName ?? "")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(date, style: .timer)
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: 84, alignment: .trailing)
        }
        .foregroundStyle(snapshot.nextKey.map { PrayerPalette.color(for: $0, scheme: colorScheme) } ?? .accentColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((snapshot.nextKey.map { PrayerPalette.color(for: $0, scheme: colorScheme) } ?? .accentColor).opacity(0.14))
        }
    }
}

struct WidgetPlaceholder: View {
    let language: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.stars")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(Translations.string("widget_needs_app", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension View {
    /// Right-to-left for `ar`/`ur`/`fa`, and the locale that decides which digits the
    /// system draws in the countdown.
    func widgetLocalized(_ snapshot: WidgetSnapshot) -> some View {
        environment(\.layoutDirection, snapshot.isRTL ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: snapshot.localeIdentifier))
    }
}
