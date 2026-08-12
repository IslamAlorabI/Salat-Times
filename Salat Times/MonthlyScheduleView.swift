import SwiftUI
import os
import AppKit
import UniformTypeIdentifiers

// A whole month of prayer times in one window — the feature that most justifies being
// on a Mac rather than a phone, and one the Android sibling deliberately doesn't have.
//
// Deliberately a `Grid`, not a `Table`. `Table` is the native-looking choice, but its
// column order does not follow `layoutDirection`, and three of the app's eight languages
// are RTL with Arabic as the *default*. A `Grid` flips for free, lets a row carry a
// background (which `Table` on macOS 13 will not do, so "today" could only have been
// marked by restyling text), and this table needs none of what `Table` adds — no
// sorting, no selection, no column resizing.
//
// The rows come from `PrayerScheduleCalculator` like everything else, so tuning, the
// fixed offsets and the Jumu'ah rename are all already applied by the time they arrive.

struct MonthlyScheduleView: View {
    @EnvironmentObject var manager: PrayerManager
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("numberFormat") private var numberFormat = "western"

    /// Any date inside the month being shown.
    @State private var anchor = Date()
    @State private var timetable: PrayerTimetable?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var loadToken = 0

    private static let columns: [PrayerKey] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if let errorMessage {
                message(errorMessage, systemImage: "wifi.slash", tint: .orange)
            } else if isLoading && timetable == nil {
                message(Translations.string("loading", language: appLanguage),
                        systemImage: "arrow.triangle.2.circlepath", tint: .secondary)
            } else {
                ScrollView {
                    grid
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }

            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(.regularMaterial)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        .task(id: monthKey) { await load() }
        // The window can sit open for days; a city or madhab change has to reach it too.
        .onChange(of: manager.settings) { _ in Task { await load() } }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                step(by: -1)
            } label: {
                Image(systemName: "chevron.backward")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .help(Translations.string("previous_month", language: appLanguage))

            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.system(size: 15, weight: .semibold))
                if let hijri = hijriSpan {
                    Text(hijri)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 220)

            Button {
                step(by: 1)
            } label: {
                Image(systemName: "chevron.forward")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .help(Translations.string("next_month", language: appLanguage))

            Spacer()

            if isLoading {
                ProgressView().controlSize(.small)
            }

            Text(manager.city)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button(Translations.string("today", language: appLanguage)) {
                anchor = Date()
            }
            .disabled(isShowingCurrentMonth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(Translations.string("schedule_footnote", language: appLanguage))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                exportCSV()
            } label: {
                Label(Translations.string("export_csv", language: appLanguage),
                      systemImage: "square.and.arrow.down")
            }
            .disabled(rows.isEmpty)

            Button {
                printSchedule()
            } label: {
                Label(Translations.string("print", language: appLanguage), systemImage: "printer")
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(rows.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func message(_ text: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private var grid: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Text(Translations.string("schedule_date", language: appLanguage))
                    .frame(width: 130, alignment: leadingEdge)
                ForEach(Self.columns, id: \.self) { key in
                    Text(Translations.string(key.translationKey(isFriday: false), language: appLanguage))
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)

            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(rows) { row in
                GridRow {
                    HStack(spacing: 6) {
                        Text(row.dayNumber)
                            .font(.system(size: 13, weight: row.isToday ? .bold : .medium))
                            .monospacedDigit()
                            .frame(width: 24, alignment: .trailing)
                        Text(row.weekday)
                            .font(.system(size: 12))
                            .foregroundColor(row.isToday ? .primary : .secondary)
                        if row.isFriday {
                            Image(systemName: "star.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.accentColor)
                                .help(Translations.string("prayer_jumuah", language: appLanguage))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: 130, alignment: leadingEdge)

                    ForEach(Self.columns, id: \.self) { key in
                        Text(row.times[key] ?? "—")
                            .font(.system(size: 13, weight: row.isToday ? .semibold : .regular))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 5)
                .background(rowBackground(row))
            }
        }
        .id(numberFormat)
    }

    @ViewBuilder
    private func rowBackground(_ row: ScheduleRow) -> some View {
        if row.isToday {
            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.18))
        } else if row.isFriday {
            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.06))
        }
    }

    private var leadingEdge: Alignment {
        Translations.isRTL(appLanguage) ? .trailing : .leading
    }

    // MARK: - Data

    /// One row per civil day, already adjusted and already Jumu'ah-aware.
    struct ScheduleRow: Identifiable {
        let id: String
        let dayNumber: String
        let weekday: String
        let isToday: Bool
        let isFriday: Bool
        let times: [PrayerKey: String]
        /// Unlocalized, for the CSV.
        let rawTimes: [PrayerKey: String]
    }

    private var calendar: Calendar {
        (timetable ?? manager.timetable).calendar
    }

    /// Changing month or settings is what re-runs the load; the string keeps `.task(id:)`
    /// from refiring on every unrelated redraw.
    private var monthKey: String {
        let c = calendar.dateComponents([.year, .month], from: anchor)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(manager.settings.requestFingerprint)"
    }

    private var isShowingCurrentMonth: Bool {
        calendar.isDate(anchor, equalTo: Date(), toGranularity: .month)
    }

    private var rows: [ScheduleRow] {
        guard let timetable else { return [] }
        let calendar = timetable.calendar
        guard let range = calendar.range(of: .day, in: .month, for: anchor),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))
        else { return [] }

        let todayStamp = DateStamp.format(Date(), in: calendar)
        let weekdayNames = localizedWeekdays(calendar: calendar)

        return range.compactMap { dayNumber -> ScheduleRow? in
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: first) else { return nil }
            let stamp = DateStamp.format(date, in: calendar)
            guard let day = timetable.days[stamp] else { return nil }

            // Same path as the popover and the scheduler, so a tune shows up here too.
            let events = PrayerScheduleCalculator.events(for: day,
                                                         calendar: calendar,
                                                         settings: manager.settings)
            var times: [PrayerKey: String] = [:]
            var raw: [PrayerKey: String] = [:]
            for event in events where !event.key.isNightMarker {
                times[event.key] = manager.formattedTime(event.date)
                raw[event.key] = Self.csvFormatter(calendar: calendar).string(from: event.date)
            }

            let weekday = calendar.component(.weekday, from: date)
            return ScheduleRow(
                id: stamp,
                dayNumber: Translations.localizedNumber("\(dayNumber)", numberFormat: numberFormat),
                weekday: weekdayNames[weekday] ?? "",
                isToday: stamp == todayStamp,
                isFriday: weekday == 6,
                times: times,
                rawTimes: raw)
        }
    }

    private func localizedWeekdays(calendar: Calendar) -> [Int: String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: Translations.locale(appLanguage))
        let symbols = formatter.shortWeekdaySymbols ?? []
        // `shortWeekdaySymbols` is Sunday-first; `Calendar.component(.weekday:)` is 1-based
        // from Sunday, so the indices line up directly.
        return Dictionary(uniqueKeysWithValues: symbols.enumerated().map { ($0.offset + 1, $0.element) })
    }

    private static func csvFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: Translations.locale(appLanguage))
        formatter.dateFormat = "LLLL yyyy"
        return Translations.localizedNumber(formatter.string(from: anchor), numberFormat: numberFormat)
    }

    /// The Hijri months this Gregorian month spans, taken from the **cached Aladhan
    /// response** rather than `Calendar(identifier: .islamicUmmAlQura)`. The two disagree
    /// by up to a day, and the popover header already uses Aladhan's — two windows of one
    /// app must never show two different Hijri dates.
    private var hijriSpan: String? {
        guard let timetable else { return nil }
        let stamps = rows.map(\.id)
        let months = stamps.compactMap { timetable.days[$0]?.hijri }
        guard let first = months.first, let last = months.last else { return nil }

        func label(_ hijri: HijriDate) -> String {
            let name = Translations.hijriMonthName(hijri.month.number, language: appLanguage)
            let year = Translations.localizedNumber(hijri.year, numberFormat: numberFormat)
            return "\(name) \(year)"
        }

        let start = label(first)
        let end = label(last)
        return start == end ? start : "\(start) — \(end)"
    }

    // MARK: - Loading

    private func step(by months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: anchor) else { return }
        anchor = moved
    }

    private func load() async {
        loadToken += 1
        let token = loadToken
        isLoading = true
        defer { if token == loadToken { isLoading = false } }

        do {
            let loaded = try await manager.monthTimetable(containing: anchor)
            guard token == loadToken else { return }
            timetable = loaded
            errorMessage = nil
        } catch {
            guard token == loadToken else { return }
            Log.data.error("Schedule window could not load a month: \(error.localizedDescription, privacy: .public)")
            // A month already on screen beats an error page; only a cold failure is fatal.
            if timetable == nil {
                errorMessage = Translations.string("check_internet", language: appLanguage)
            }
        }
    }

    // MARK: - Export

    /// Deliberately unlocalized: `yyyy-MM-dd` and 24-hour `HH:mm` in western digits, with
    /// the API's English prayer keys as headers. A CSV is going into a spreadsheet, not
    /// being read as prose — Arabic-Indic numerals and RTL headers make it unparseable.
    private var csv: String {
        var lines = ["Date,Weekday," + Self.columns.map(\.rawValue).joined(separator: ",")]
        let calendar = self.calendar
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.timeZone = calendar.timeZone
        weekdayFormatter.dateFormat = "EEEE"

        for row in rows {
            let date = DateStamp.startOfDay(row.id, in: calendar)
            let weekday = date.map { weekdayFormatter.string(from: $0) } ?? ""
            let times = Self.columns.map { row.rawTimes[$0] ?? "" }
            lines.append(([row.id, weekday] + times).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(manager.city.replacingOccurrences(of: " ", with: "-"))-\(csvMonthStamp).csv"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            Log.data.notice("Exported schedule CSV")
        } catch {
            Log.data.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private var csvMonthStamp: String {
        let c = calendar.dateComponents([.year, .month], from: anchor)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// Prints the grid by re-rendering it into an off-screen hosting view sized to the
    /// paper, rather than printing the window: the on-screen view is inside a `ScrollView`
    /// and would otherwise print only the visible rows.
    private func printSchedule() {
        let info = NSPrintInfo.shared
        info.orientation = .portrait
        info.topMargin = 36
        info.bottomMargin = 36
        info.leftMargin = 36
        info.rightMargin = 36
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic

        let width = info.paperSize.width - info.leftMargin - info.rightMargin

        let page = VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(monthTitle).font(.system(size: 16, weight: .bold))
                Text(manager.city).font(.system(size: 12))
                if let hijriSpan {
                    Text(hijriSpan).font(.system(size: 11))
                }
            }
            grid
        }
        .padding(16)
        .frame(width: width)
        .environment(\.layoutDirection, Translations.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        // Printing on white paper: force the light appearance so a dark-mode Mac does not
        // print white text.
        .environment(\.colorScheme, .light)

        let hosting = NSHostingView(rootView: page)
        hosting.frame = NSRect(origin: .zero,
                               size: NSSize(width: width, height: hosting.fittingSize.height))

        let operation = NSPrintOperation(view: hosting, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.jobTitle = "\(manager.city) — \(monthTitle)"
        operation.run()
    }
}
