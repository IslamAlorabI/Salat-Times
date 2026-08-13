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
    @State private var rowCache = RowCache()

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

            Text(cityName)
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

            Menu {
                Button(Translations.string("export_pdf", language: appLanguage)) { exportPDF() }
                Button(Translations.string("export_png", language: appLanguage)) { exportPNG() }
                Divider()
                Button(Translations.string("export_csv", language: appLanguage)) { exportCSV() }
            } label: {
                Label(Translations.string("export", language: appLanguage),
                      systemImage: "square.and.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(rows.isEmpty)

            Button {
                printSchedule()
            } label: {
                Label(Translations.string("print", language: appLanguage), systemImage: "printer")
            }
            .disabled(rows.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        // ⌘P is claimed by AppKit's own responder chain before a SwiftUI button's
        // `.keyboardShortcut` sees it, and the default handler answers with "This
        // application does not support printing". The shortcut is now declared once as a
        // real menu command (`CommandGroup(replacing: .printItem)`) which posts this.
        .onReceive(NotificationCenter.default.publisher(for: .printSchedule)) { _ in
            guard !rows.isEmpty else { return }
            printSchedule()
        }
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

    /// Plain `.leading`, never `isRTL ? .trailing : .leading`. SwiftUI already resolves
    /// `.leading` against `layoutDirection`, so that ternary flipped it a *second* time
    /// and parked the date header on the opposite side of its own column from the dates
    /// beneath it.
    private var leadingEdge: Alignment { .leading }

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

    /// Identifies a built month. Everything `computeRows` reads is in here, so a hit is
    /// only ever possible when recomputing would produce exactly the same rows.
    ///
    /// `todayStamp` is a field rather than an afterthought: it is what moves the "today"
    /// highlight at midnight, and without it a window left open overnight would keep
    /// marking yesterday.
    struct RowKey: Equatable {
        let timetable: PrayerTimetable?
        let month: String
        let settings: PrayerSettings
        let language: String
        let numberFormat: String
        let todayStamp: String
        /// The cells are formatted by `manager.formattedTime`, which reads the *manager's*
        /// timetable for its zone — not this window's. Those are normally the same, but
        /// they are not the same *object*: with the window restored at launch, this view
        /// can have loaded its month before the manager has loaded its own, and the zone
        /// would change underneath without any other key field moving.
        let formattingZone: String
    }

    /// Deliberately a reference type held by `@State`, not a `@State` value: this is
    /// written *during* body evaluation, and assigning to `@State` there is "Modifying
    /// state during view update". Mutating an object SwiftUI isn't observing is not.
    final class RowCache {
        var key: RowKey?
        var rows: [ScheduleRow] = []
    }

    /// The month, built at most once per set of inputs.
    ///
    /// It is read four times in a single render — twice by `.disabled(rows.isEmpty)`, once
    /// by the grid, once by the Hijri header — and the window re-renders every second,
    /// because it observes `PrayerManager` and the countdown publishes on a one-second
    /// timer. Building a month measured ~76 ms, so scrolling was competing with roughly
    /// 300 ms of main-thread work every second. Now the first read builds it and the rest
    /// of that second are cache hits.
    private var rows: [ScheduleRow] {
        let key = RowKey(timetable: timetable,
                         month: monthKey,
                         settings: manager.settings,
                         language: appLanguage,
                         numberFormat: numberFormat,
                         todayStamp: DateStamp.format(Date(), in: calendar),
                         formattingZone: manager.timetable.timeZone.identifier)

        if let cached = rowCache.key, cached == key { return rowCache.rows }

        let built = computeRows()
        rowCache.key = key
        rowCache.rows = built
        return built
    }

    private func computeRows() -> [ScheduleRow] {
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

    /// Kept between calls for the same zone, for the same reason `formattedTime` keeps its
    /// own: this is asked for once per prayer per day, and building the formatter cost far
    /// more than formatting with it.
    private static var cachedCSVFormatter: (zone: String, formatter: DateFormatter)?

    private static func csvFormatter(calendar: Calendar) -> DateFormatter {
        let zone = calendar.timeZone.identifier
        if let cached = cachedCSVFormatter, cached.zone == zone { return cached.formatter }

        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        cachedCSVFormatter = (zone, formatter)
        return formatter
    }

    /// The city as the rest of the app names it. `manager.city` is the `City` enum's raw
    /// value — always English, e.g. "Kuala Lumpur" — which is not what the popover, the
    /// header or an Arabic reader sees anywhere else.
    private var cityName: String {
        City.allCases.first { $0.rawValue == manager.city }?.getName(language: appLanguage)
            ?? manager.city
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
        // Attribution goes in a `#` preamble rather than in the table. Every spreadsheet
        // and CSV parser worth using skips comment lines, so the data still starts at a
        // real header row — putting the credit in row 1 would shift every column.
        var lines = [
            "# \(Self.exportCredit)",
            "# \(cityName) — \(monthTitle)",
            "# generated \(generatedStamp)",
            "Date,Weekday," + Self.columns.map(\.rawValue).joined(separator: ","),
        ]
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
        save(Data(csv.utf8), extension: "csv", type: .commaSeparatedText)
    }

    private var csvMonthStamp: String {
        let c = calendar.dateComponents([.year, .month], from: anchor)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    // MARK: - The printable page

    /// A4 in points. Print, PDF and PNG are all sized to it. None of them can reuse the
    /// on-screen grid: it lives in a `ScrollView`, so it would only ever render the rows
    /// currently scrolled into view.
    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let pageMargin: CGFloat = 36

    /// Deliberately unlocalized and unlocalizable-by-numerals: this is attribution, and it
    /// should read the same on every exported sheet whatever the app's language.
    /// Keep the year in step with `AboutView.copyrightYear`.
    ///
    /// The data source is credited in About, not here — an exported sheet is the app's own
    /// output and carries the app's name only.
    private static let exportCredit = "Salat Times · © 2026 Islam AlorabI"

    /// When the sheet was produced, so a printout found on a desk months later can be
    /// told apart from a current one. ISO, for the same reason the CSV is.
    private var generatedStamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }

    /// One definition of the page, shared by all three outputs so they cannot drift.
    @ViewBuilder
    private func page(width: CGFloat) -> some View {
        let isRTL = Translations.isRTL(appLanguage)
        VStack(alignment: .leading, spacing: 12) {
            // Masthead: the app's own icon and name, so an exported sheet still says where
            // it came from once it is out of the app and in someone's inbox.
            HStack(alignment: .center, spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(monthTitle).font(.system(size: 16, weight: .bold))
                    Text(cityName).font(.system(size: 12))
                    if let hijriSpan {
                        Text(hijriSpan)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Text(Translations.string("app_name", language: appLanguage))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Divider()

            grid

            Divider()

            HStack(spacing: 6) {
                Text(Self.exportCredit)
                Spacer(minLength: 8)
                Text(generatedStamp)
            }
            .font(.system(size: 8))
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: width)
        .background(Color.white)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Translations.locale(appLanguage)))
        // Onto white paper: force the light appearance so a dark-mode Mac does not render
        // white text on white.
        .environment(\.colorScheme, .light)
    }

    /// All three outputs go through `ImageRenderer`, and none of them through a hosting
    /// view's own AppKit drawing.
    ///
    /// An `NSHostingView` puts most of what SwiftUI draws into CALayers, and both
    /// `dataWithPDF(inside:)` and `NSPrintOperation`'s draw pass record only what a view
    /// draws into the context *itself*. Text arrived, so the sheets looked plausible — but
    /// the masthead icon and the today/Friday row fills were silently dropped, and the PDF
    /// and the printout disagreed with the PNG of the same page (that one went through
    /// `cacheDisplay`, which does composite the layers). Measured on a page carrying an
    /// icon and a filled row: `dataWithPDF` recorded the text and nothing else.
    ///
    /// `ImageRenderer` replays the content into whatever context it is handed, so the three
    /// outputs cannot disagree, and PDF text stays vector rather than being rasterised.
    private func pageRenderer() -> ImageRenderer<AnyView> {
        let width = Self.pageSize.width - Self.pageMargin * 2
        let renderer = ImageRenderer(content: AnyView(page(width: width)))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer
    }

    /// The laid-out size of the page. `render` is the only thing that reports it.
    private func renderedSize(of renderer: ImageRenderer<AnyView>) -> CGSize {
        var size = CGSize.zero
        renderer.render { measured, _ in size = measured }
        return size
    }

    private func printSchedule() {
        let renderer = pageRenderer()
        let size = renderedSize(of: renderer)
        guard size.height > 0 else {
            Log.data.error("Could not lay out the schedule for printing")
            return
        }

        // A plain view sized to the whole month, drawing the page through the renderer.
        // AppKit still paginates it: it slices this view into page-height strips and
        // translates the context for each, so the draw below lands correctly on every page.
        let sheet = RenderedPageView(frame: NSRect(origin: .zero, size: size))
        sheet.drawContent = { context in
            renderer.render { _, draw in draw(context) }
        }

        let info = NSPrintInfo.shared
        info.orientation = .portrait
        info.topMargin = Self.pageMargin
        info.bottomMargin = Self.pageMargin
        info.leftMargin = Self.pageMargin
        info.rightMargin = Self.pageMargin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic

        let operation = NSPrintOperation(view: sheet, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.jobTitle = "\(cityName) — \(monthTitle)"
        if !operation.run() {
            Log.data.error("Print operation did not complete")
        }
    }

    /// One page, A4-wide and as tall as the month needs — the same shape the PNG has.
    private func exportPDF() {
        guard let data = renderedPDF() else {
            Log.data.error("Could not render the schedule as PDF")
            return
        }
        save(data, extension: "pdf", type: .pdf)
    }

    private func renderedPDF() -> Data? {
        let renderer = pageRenderer()
        let buffer = NSMutableData()
        guard let consumer = CGDataConsumer(data: buffer) else { return nil }

        var didRender = false
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            didRender = true
        }
        return didRender ? buffer as Data : nil
    }

    /// The same page rasterised at 2×, for dropping into a chat or printing elsewhere.
    /// The scale is the renderer's, so this really is 2× — the old `cacheDisplay` path took
    /// its resolution from the backing store of an off-screen window, which is 1×.
    private static let exportScale: CGFloat = 2

    private func exportPNG() {
        let renderer = pageRenderer()
        renderer.scale = Self.exportScale
        guard let image = renderer.cgImage else {
            Log.data.error("Could not rasterise the schedule")
            return
        }
        let rep = NSBitmapImageRep(cgImage: image)
        // Without this the PNG reports 2× its point size as its size, and lands in a
        // document at double scale.
        rep.size = NSSize(width: CGFloat(image.width) / Self.exportScale,
                          height: CGFloat(image.height) / Self.exportScale)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            Log.data.error("Could not encode the schedule as PNG")
            return
        }
        save(png, extension: "png", type: .png)
    }

    private func save(_ data: Data, extension ext: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "\(manager.city.replacingOccurrences(of: " ", with: "-"))-\(csvMonthStamp).\(ext)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            Log.data.notice("Exported schedule as \(ext, privacy: .public)")
        } catch {
            Log.data.error("Export failed: \(error.localizedDescription, privacy: .public)")
            NSAlert(error: error).runModal()
        }
    }
}

/// A view that draws nothing of its own and hands its context to a closure — the print
/// job's page, drawn by `ImageRenderer` rather than by a hosting view's layers.
///
/// It is deliberately not flipped: `ImageRenderer` draws for a bottom-left origin (which is
/// what made the PDF path work), and an unflipped `NSView` gives exactly that. Sized to the
/// full month, so AppKit's automatic pagination slices it into pages.
private final class RenderedPageView: NSView {
    var drawContent: ((CGContext) -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        drawContent?(context)
        context.restoreGState()
    }
}

extension Notification.Name {
    /// Posted by the File ▸ Print command. ⌘P has to be declared as a real menu command,
    /// because AppKit's responder chain claims it before a SwiftUI button's
    /// `.keyboardShortcut` ever sees it — and answers with "This application does not
    /// support printing".
    static let printSchedule = Notification.Name("islam.salattimes.printSchedule")
}
