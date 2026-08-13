# Salat Times — macOS menu bar prayer times app

SwiftUI menu-bar-only app (`LSUIElement`) showing Islamic prayer times with a live countdown,
plus a WidgetKit extension. No dependencies, no tests.

Two targets — `Salat Times` (the app) and `SalatTimesWidgetExtension` (the widget) — and **three**
synchronized root groups: `Salat-Times/` belongs to the app, `SalatTimesWidget/` to the widget, and
`Shared/` is listed by *both*. That is how the widget compiles `Core/`, the translation tables and
`PrayerPalette` without a copy or a per-file membership list to keep in step. Anything a second
process needs goes in `Shared/`; anything that is the app's own UI does not.

## Build & run

```bash
xcodebuild -project "Salat-Times.xcodeproj" -scheme "Salat Times" -configuration Debug build
```

- **The project file and the source folder are `Salat-Times`; the scheme, the target and the
  product are still `Salat Times` with a space.** Both spellings are live at once, so quote
  everything: `-project "Salat-Times.xcodeproj" -scheme "Salat Times"`. Renaming the folder on
  2026-08-13 touched exactly one line of `project.pbxproj` — the
  `PBXFileSystemSynchronizedRootGroup`'s `path` — because everything else bearing the old name is a
  target/product name rather than a filesystem path.
- The app has **no test target** (adding one needs a one-time Xcode GUI step). Instead, the pure `Core/` types have behaviour checks that compile with `swiftc`:

```bash
./Checks/run.sh
```

  Run these after touching anything in `Shared/Core/`, and add a case when you fix a bug there. `./Checks/run.sh --network` additionally exercises `Data/` against the live Aladhan API and the disk cache. Everything else — notification delivery, menu bar rendering, RTL layout — still has to be checked by hand.
- Product lands in `~/Library/Developer/Xcode/DerivedData/Salat-Times-*/Build/Products/Debug/Salat Times.app`. (Renaming the project moved this: anything still under `Salat_Times-*`, with the underscore, is from before 2026-08-13 and is stale.)
- `build_output.txt` at the repo root is a stale local log (git-ignored, never committed) — don't rely on it.

The project uses `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`, and the target lists
that group in `fileSystemSynchronizedGroups`, so **new `.swift` files dropped into `Salat-Times/` are
picked up automatically** — no `project.pbxproj` edits needed. Anything placed in that folder is a
build input, which is why the simulator `.gpx` files live in a top-level `Simulator GPX/` folder
instead.

> Before 2026-08-12 the target had no `fileSystemSynchronizedGroups` key, which inverted the meaning
> of the `PBXFileSystemSynchronizedBuildFileExceptionSet` — `membershipExceptions` acted as an
> *inclusion* list and every new file had to be added to it by hand. That exception set has been
> removed. If a newly added file ever fails to compile with "cannot find X in scope", check that the
> target still has its `fileSystemSynchronizedGroups` entry.

## Layout

| File | Role |
| --- | --- |
| `Salat-Times/SalatTimesApp.swift` | `@main`. `MenuBarExtra` (window style) + `settings`, `schedule` and `welcome` `Window` scenes. |
| `Shared/Core/` | Pure, `nonisolated`, I/O-free model + calculation types. No SwiftUI, no network. Shared by everything and covered by `Checks/`. The one `UserDefaults` touch is `PrayerSettings.load(from:)`, which takes the store as a parameter so the checks can pass a scratch suite. Also holds `City`/`Continent` and `NotificationSound`/`PrayerNotificationSettings`. |
| `Salat-Times/PrayerManager.swift` | The one `ObservableObject`: fetch, countdown timer, notifications, the settings diff, location. |
| `Salat-Times/ContentView.swift` | Menu bar popover: hijri header, countdown, six prayer rows, the two night markers, footer. |
| `Salat-Times/SettingsView.swift` | Settings window: a `TabView` over `GeneralSettingsTab` / `PrayerTimesSettingsTab` / `NotificationSettingsTab`, plus the shared picker components. |
| `Salat-Times/CalculationSettingsView.swift` | The madhab, high-latitude and midnight-mode sections, per-prayer tuning, and the Fajr/Isha fixed offsets. Lives in the Prayer Times tab. |
| `Salat-Times/MonthlyScheduleView.swift` | The `schedule` window: a month of times, CSV export, `⌘P` print. |
| `Salat-Times/WelcomeView.swift` | First-launch onboarding, gated on `hasShownWelcome`. |
| `Salat-Times/LocationControls.swift` | The mode picker and the three source rows, shared by Settings and the welcome sheet. |
| `Salat-Times/MapLocationPicker.swift` | The MapKit sheet: click to drop a pin, `MKLocalSearch`, typed coordinates. |
| `Shared/Translations/` | Lookup + numeral/RTL helpers. The strings themselves live in `Translations+UI/Methods/Prayer/Hijri/Settings.swift`. |

## The widget

`SalatTimesWidget/` is a **reader**. It renders from the App Group container the app already
maintains — the settings suite and the cached months — and never fetches: it has no network
entitlement, and two processes asking an API with no SLA for the same month is exactly the traffic
the month-granularity cache exists to avoid. If the cache is empty it says so ("open the app")
rather than drawing an empty grid.

- **A widget cannot tick.** WidgetKit renders a timeline and shows each entry until the next, so a
  per-second countdown cannot be pushed. `Text(date, style: .timer)` is the way out — the system
  animates it without waking anything. The timeline is one entry per upcoming prayer for 24 hours
  with `.atEnd`, so it re-renders exactly when the answer changes.
- **`PrayerEvent` carries no time zone** — it is an absolute instant. The zone travels on the
  entry, or the widget renders the city's times in the Mac's zone.
- `WidgetCenter.shared.reloadAllTimelines()` is called from `applySettingsChange` and after a fetch
  lands. Without it the widget shows the old city until its own timeline happens to expire.
- **`containerBackground` is mandatory from macOS 14, and forgetting it does not look like a
  styling bug.** The system refuses to draw the widget at all and substitutes "Please adopt
  containerBackground API", which reads as the widget being broken. It must be applied to *every*
  widget's entry view: the `.widget` placement comes from WidgetKit, and `WidgetViews.swift` is
  deliberately WidgetKit-free so its layouts can be rendered off-screen, so there is no shared root
  to hang it on. Guarded with `#available(macOS 14.0, *)` because the app's floor is 13.0.
- Xcode's template gave the new target `MACOSX_DEPLOYMENT_TARGET = 26.2` and no App Group. Both were
  corrected by hand; a widget without the group entitlement sees neither settings nor cache and
  renders the placeholder for ever, which looks exactly like a broken widget.
- If the widget stops appearing in the gallery, check which copy is registered:
  `pluginkit -m -v -p com.apple.widgetkit-extension | grep -i salat`. It follows the most recently
  seen build, so a DerivedData copy can shadow the one in `/Applications`.

## Conventions that matter

**Localization is a hand-rolled dictionary, not `.strings` files.**
`Translations.string("key", language: appLanguage)` reads a merged `[key: [langCode: value]]` map
built once from the file-scope tables in `Translations+*.swift` (`uiStrings`, `methodStrings`,
`prayerStrings`, `hijriStrings`, `settingsStrings`). Eight languages, and every key must carry all
eight: `ar`, `en`, `ru`, `id`, `tr`, `ur`, `fa`, `de`. Missing keys silently fall back to `en`, then
to the raw key — so adding a string means one entry of eight lines in the right domain table.
`ar`, `ur`, `fa` are RTL. Default language is `"ar"`, not `"en"` — every `UserDefaults` read of
`appLanguage` uses `?? "ar"`.

Keep the tables split by domain and at file scope. They were one literal inside `string()` until it
reached ~1,100 lines; a single large nested dictionary literal in a function body makes the Swift
type-checker crawl and eventually fails outright with "unable to type-check this expression in
reasonable time".

**Numerals are localized separately** via `Translations.localizedNumber(_:numberFormat:)`
(`western` / `arabic` / `persian`). Views that display numbers use `.id(numberFormat)` to force a
rebuild when it changes.

**State lives in `UserDefaults`, read two ways.** Views use `@AppStorage`; `PrayerManager` reads
`UserDefaults.standard` directly. Keys:

- `appLanguage` (default `"ar"`), `selectedCityRaw`, `calculationMethod` (`0` means unset → Aladhan method `5`), `timeFormat24`, `numberFormat`, `hasShownWelcome`
- `reminderInterval`, `warningInterval` — minutes; `0` disables
- `notification_<Prayer>_enabled` / `notification_<Prayer>_sound` for each of `Fajr Sunrise Dhuhr Asr Maghrib Isha`
- `asrSchool` (`0` Shafi'i / `1` Hanafi), `latitudeAdjustment` (`0`–`3`; `0` is a real value, NONE, not "unset"), `midnightMode` (`0` standard / `1` Jafari) — request fields
- `tune_<Prayer>` — minutes, `-30…30`; `fajrBeforeSunriseMinutes` / `ishaAfterMaghribMinutes` — `0` disables, otherwise clamped to `15…180`. All applied on read

Every one of these is clamped in `PrayerSettings.load(from:)` rather than trusted, so a bad stored
value can't reach a request URL or an instant.

**Settings take effect through one debounced diff, not per-control hooks.**
`PrayerManager.observeSettingsChanges()` watches `UserDefaults.didChangeNotification`, coalesces the
burst (250 ms), reloads the `PrayerSettings` snapshot and compares it with the previous one. A change
to `requestFingerprint` refetches; anything else just rebuilds events and reconciles notifications.
**So a new setting takes effect because `PrayerSettings.load` reads its key — not because a view
remembered to wire it.** The only `.onChange` left in `SettingsView` writes *another* preference
(picking a city sets the recommended method); don't add ones that merely call back into the manager.

> Before 2026-08-12 each control wired its own `.onChange` to `manager.loadSavedCity()` /
> `updateCountdown()` / `schedulePrayerNotifications()`, and a setting without a hook silently did
> nothing — `timeFormat24` and `warningInterval` had both been shipped that way.

**`PrayerScheduleCalculator` is the only code allowed to turn a wall-clock string into a `Date`.**
The menu bar timer, the popover's `TimelineView`, and the notification scheduler all consume
`PrayerScheduleCalculator.events(around:timetable:settings:)` — a sorted window of `PrayerEvent`s
spanning yesterday through two days ahead. Ask it for `next(after:)` / `current(at:)` rather than
recomputing. Two rules make it correct, and both are easy to undo by accident:

- Instants resolve through a `Calendar` pinned to the **city's** `TimeZone` (from the API's
  `meta.timezone`), never `Calendar.current`. A city in another zone counted down wrongly until this
  was fixed.
- No "if the time already passed, add a day" anywhere. The rolling window makes Isha→Fajr, the last
  third landing after midnight, and date rollover fall out for free.

**Prayer keys are the Aladhan API's English names**, modelled by `PrayerKey` whose `rawValue` is that
name. The same string is the fragment in `notification_<Key>_enabled`, so cases can be added without
migrating preferences. `Midnight` and `Lastthird` come straight from the API — don't recompute them.
Friday renaming is resolved once into `PrayerEvent.translationKey`; never special-case Fridays in a view.

**Adjustments are applied on read, never stored.** `PrayerAdjustments` re-applies per-prayer tuning
and the Fajr/Isha fixed offsets each time a day is read, so changing an offset must never invalidate
cached data. `PrayerSettings.requestFingerprint` covers only the fields that change what the *server*
returns — city coordinates, `method`, `school`, `latitudeAdjustment`, `midnightMode`. All four
non-coordinate axes were verified against the live API (Hanafi moves Cairo's Asr 16:37 → 17:44;
Jafari moves Midnight 01:00 → 00:12; `latitudeAdjustmentMethod` is echoed in `meta` as
`NONE`/`MIDDLE_OF_THE_NIGHT`/`ONE_SEVENTH`/`ANGLE_BASED`).

The popover shows `Midnight` and `Lastthird` below a divider in a quieter style
(`PrayerRow(isSecondary:)`), because nothing counts down to them and nothing notifies for them.
Note their instants are attributed to the `dateStamp` they are *listed under*, which is the day
before the small hours they actually fall in — the rendered clock is right, but don't build anything
that fires on a night marker's `date` without resolving that first.

## The two windows

**Settings is three tabs, not one column.** Twelve `GroupBox`es in a single `ScrollView`
ran to about twice the window height. Each tab is a `SettingsTabScroll` and owns its own
`@AppStorage`; none of them wire a control back to `PrayerManager` — the debounced diff
does that. Only two `manager` calls remain in the whole window, and both are real actions:
"refresh now" and `refreshAuthorizationStatus()` on the notifications tab (the denial
banner used to be captured once at launch, so granting permission left it stuck on screen).

**`MonthlyScheduleView` uses `Grid`, not `Table`.** `Table` is the native-looking choice
and the one to reach for by default, but its column order does not follow
`layoutDirection` — and `ar`/`ur`/`fa` are RTL with Arabic the *default* language. `Grid`
also lets a row carry a background, which is how "today" and Fridays are marked; `Table`
on macOS 13 cannot, so they could only have been shown by restyling text. Nothing here
needs sorting, selection or resizable columns. Rows come from
`PrayerScheduleCalculator.events(for:)` like everywhere else, so tuning, fixed offsets and
the Jumu'ah rename arrive already applied.

Three things in that window are easy to get wrong:

- The **Hijri span in the header reads Aladhan's `date.hijri` from the cache**, never
  `Calendar(identifier: .islamicUmmAlQura)`. The two disagree by up to a day and the
  popover header already uses Aladhan's — one app must not show two different Hijri dates.
- The **CSV is deliberately unlocalized**: `yyyy-MM-dd`, 24-hour `HH:mm`, western digits,
  English `PrayerKey` headers. It goes into a spreadsheet, and Arabic-Indic numerals plus
  RTL headers make it unparseable.
- **Print, PDF and PNG all re-render the page off-screen** rather than capturing the
  window, because the on-screen grid is inside a `ScrollView` and would only ever emit the
  visible rows. One `page(width:)` defines the sheet for all three, and it forces
  `.colorScheme(.light)` so a dark-mode Mac doesn't print white text on white paper.
- **That off-screen render must go through `ImageRenderer`, never an `NSHostingView`.**
  A hosting view puts most of what SwiftUI draws into CALayers, and both
  `dataWithPDF(inside:)` and `NSPrintOperation`'s draw pass record only what the view draws
  into the context itself. Text came through and everything else — the masthead app icon,
  the today/Friday row fills — was silently dropped, so the PDF and the printout were
  quietly wrong while the PNG (via `cacheDisplay`, which does composite layers) was right.
  Printing uses `RenderedPageView`, a bare unflipped `NSView` that hands its `CGContext` to
  the renderer; AppKit still paginates it.
- The **export credit is the app's own name only** — `"Salat Times · © <year> …"`. The data
  source is credited in About, not stamped on every exported sheet.
- **`rows` is memoised, and `DateFormatter`s are never built per cell.** The window observes
  `PrayerManager`, whose countdown publishes every second, so its body re-renders once a
  second whether or not anything it shows has changed — and `rows` is read four times per
  render (twice for `.disabled`, once by the grid, once by the Hijri header). Measured, a
  month cost ~76 ms to build, ~63 ms of which was constructing a `DateFormatter` per prayer
  per day, twice (display + CSV). That was ~300 ms of main-thread work per second and it
  made scrolling stutter. Two fixes, neither of which changes a single rendered string
  (verified: 2016/2016 identical across all eight languages × 12/24-hour × three numeral
  systems): `formattedTime` and `csvFormatter` keep their formatter and rebuild it only when
  zone/language/format moves, and `rows` is cached behind `RowKey`.
  `RowKey` must keep covering **everything** `computeRows` reads, or the window shows stale
  times: the timetable, the month, the settings, language, numerals, `todayStamp` (which is
  what moves the "today" highlight at midnight) and `formattingZone` — that last one because
  `formattedTime` takes its zone from the *manager's* timetable, not this window's, and the
  two can differ briefly at launch.

The stepper walks to arbitrary months via `PrayerRepository.month(containing:settings:)`,
which is separate from `load(around:)` — the latter deliberately only fetches the months
the *scheduler* needs. Same cache-first contract, so browsing back is free.

## External API and caching

`https://api.aladhan.com/v1/calendar/{year}/{month}` — **a month per request**, not a day. Aladhan
has no SLA, no auth and undocumented rate limits, so month-granularity plus a 30-day cache is the
whole defence; don't reintroduce per-day fetching.

`Data/PrayerRepository` is an `actor` and is cache-first: it serves `Core/MonthCacheStore` JSON from
Application Support, goes to the network only when a month is missing or stale, and **falls back to
stale cache when the network fails** rather than showing an empty screen. `lastUpdatedFromServer` +
`isServingStaleData` drive the green/orange sync dot.

Two response quirks worth knowing:

- `/v1/calendar` returns `"04:36 (EEST)"` while `/v1/timings` returns a bare `"04:36"`.
  `DayTimings.parseMinutes` reads only the leading clock and drops anything that isn't a real time.
- `date.gregorian.date` is `DD-MM-YYYY`; `GregorianDate.dateStamp` normalises it to `yyyy-MM-dd`,
  which is what keys a `PrayerTimetable`.

## Lifecycle

`Services/PrayerLifecycle` is what keeps a menu bar app that runs for weeks honest. The primary
mechanism is a **self-re-arming one-shot `Timer`** at the next prayer or the city's midnight,
whichever comes first, added to `RunLoop.main` in `.common` mode (otherwise it stalls while a menu is
being tracked). `PrayerManager.rebuildEvents()` re-arms it — if you add a path that changes the
schedule, route it through there or the app goes quiet again.

It also watches `NSWorkspace.didWakeNotification`, `NSCalendarDayChanged`, `NSSystemClockDidChange`,
`NSSystemTimeZoneDidChange`, `NSApplication.didBecomeActiveNotification`, and an `NWPathMonitor` for
the offline→online transition. Don't use `NSCalendarDayChanged` as the *data* trigger: it fires on
the device's rollover, not the city's.

## Notifications

`Services/PrayerNotificationScheduler.reconcile` diffs the desired set against
`pendingNotificationRequests()` and adds/removes only the delta. Two properties it must keep:

- **Idempotent.** Identifiers are `prayer_<Key>_<yyyy-MM-dd>_<notificationFingerprint>`. Same
  settings → same identifiers → no churn; changed settings → all identifiers rotate, so the old ones
  fall out of the desired set and are removed. Never go back to clear-then-rebuild.
  A request's **sound is fixed when it is added**, so the per-prayer sounds are part of that
  fingerprint — without them the reconciler saw a matching identifier and left the already-pending
  alerts playing the old sound. `enabledPrayers` is deliberately *not* in it: disabling already drops
  a prayer from the desired set, and folding it in would rewrite every other prayer's requests for
  nothing. `reconcile` reads both off the `PrayerSettings` snapshot, not `UserDefaults`, so what is
  scheduled is exactly what the manager diffed.
- **Multi-day, within the cap.** `UNUserNotificationCenter` keeps 64 pending requests and silently
  discards the furthest-future ones past that. `horizonDays` budgets against it (6 prayers +
  reminders ≈ 5 days) and the boundary timer slides the window forward on every prayer.

- **Delivered notifications are swept, because nothing expires on its own.** Notification Center
  keeps every alert until the user clears it, so six a day (twelve with reminders) becomes a wall.
  `staleDelivered` — pure, and checked — names two kinds: anything delivered **before the current
  prayer** (so a reminder is replaced by its prayer's alert, and that alert goes when the next
  prayer arrives — at most two on screen ever), and anything delivered **in the future**, which is
  what a clock jumping forward and back leaves behind. Future-dated ones matter: their date never
  becomes old, so without that rule they would sit there for ever. `PrayerManager` calls
  `pruneDeliveredNotifications()` from the boundary, wake and became-active hooks.
- **A pending request's content is frozen when it is added**, so changing what a notification says
  or how it groups cannot reach the ones already scheduled — up to a week of them.
  `PrayerSettings.notificationContentVersion` is folded into `notificationFingerprint` for exactly
  that: bump it and every identifier rotates once, the reconciler drops the old requests and adds
  them back in the new shape. Bumping it also moves the golden fingerprint pinned in `Checks/`,
  which must be re-pinned deliberately — an *unintended* change there means someone reintroduced a
  per-process hash.
- A prayer and its own reminder share a `threadIdentifier`, so Notification Center stacks them as
  one entry rather than two unrelated rows.

`pendingNotificationRequests()` is **eventually consistent** — right after a batch of adds, and early
in startup, it under-reports. Measured: it returned 47 while the store genuinely held all 60. Don't
shrink the horizon to chase that number. To check what is really scheduled, read the store:

```bash
sqlite3 ~/Library/Group\ Containers/group.com.apple.usernoted/db2/db "SELECT COUNT(*) FROM record WHERE app_id=(SELECT app_id FROM app WHERE identifier='islam-alorabi.salat-times');"
```

  Note that table also retains rows for requests already removed or delivered, so filter on
  `delivered_date IS NULL` and check the identifier format before drawing conclusions.

Every trigger sets `components.timeZone` to the city's zone — without it the trigger is device-local
and the timezone work in `Core` is undone at the last step. Sounds map to
`/System/Library/Sounds/<Name>.aiff`. Permission denial is surfaced in Settings; it used to be only
`print`ed, which silently voided everything above.

## Menu bar

`menuBarTitle` is `"<prayer> · <countdown>"`, recomputed every second by a `Timer` in `PrayerManager`
and assigned only when it actually changes (unconditional assignment invalidated the menu bar ~86,400
times a day). It was `"<prayer> -<countdown>"` until the hyphen was read as a minus sign.
`isWarningActive` flips the icon to `bell.badge.fill` when the countdown drops under `warningInterval`
minutes.

The popover runs its own `TimelineView(.periodic(by: 1.0))`, so its countdown and the menu bar's are
computed independently and must stay in agreement — that is what `Countdown` is for.

**Inside the popover, everything time-dependent must come from the same `context.date`.** The
countdown was driven by the timeline while the row highlight was computed from a bare `Date()` in the
enclosing body: the countdown re-rendered every second, the highlight only when something else
invalidated the view, so once a prayer passed the two could name different prayers until an unrelated
redraw fixed it. `next(after:)` and `progress(at:in:)` are now both called with `context.date`.

**One translucent layer, not five.** The window carries `.ultraThinMaterial` and nothing else does.
It previously had material on the window, the header, the footer, the countdown card *and* every
prayer row, each with its own stroke — stacked translucency turns to mud, and eight bordered rows
read as eight buttons instead of a list. Depth comes from solid low-opacity fills over the one
material; only the next prayer's row is drawn at all. `PrayerPalette` holds the per-prayer colours,
in the app target rather than `Core/`, because `Core/` must not import SwiftUI.

## Notes

- Deployment target macOS 13.0, Swift 5, bundle id `Islam-AlorabI.Salat-Times`, version 3.0 (also hardcoded as `"v3.0"` in `ContentView`'s footer — update both). The *project-level* deployment target is 15.7; only the app target overrides it to 13.0.0, so any new target inherits 15.7 unless told otherwise.
- **State lives in an App Group container, not the app's own sandbox.** `Core/SharedStore` is the
  only thing that knows the group's name, and a widget — a separate process in its own sandbox —
  is why: it can see neither `UserDefaults.standard` nor the app's Application Support folder.
  - `SharedStore.defaults` is the group suite, falling back to `.standard` when the container is
    absent (unsigned or ad-hoc builds have none). That fallback is load-bearing: without it every
    setting would read as its default and the app would behave like a fresh install.
  - The 71 `@AppStorage` properties are *not* annotated individually — `.defaultAppStorage(...)` on
    each scene root in `SalatTimesApp` redirects them all at once.
  - `SharedStore.migrateIfNeeded` copies this app's keys across once, on the `App`'s `init` so it
    runs before `PrayerManager` loads its first snapshot. It **copies, never moves** (a build
    without the group still finds the originals), never overwrites a value already in the
    destination, and works from an owned-key list — `UserDefaults` is full of things AppKit put
    there. On macOS the group id must carry the team prefix; a bare `group.…` yields a nil container.
  - `AppPaths.supportDirectory` follows the same rule, and `migrateCacheIfNeeded` moves the cached
    months over so an app updated while offline still has times to show.
- **There is no `.entitlements` file** — except one line of it. Entitlements are synthesized from build settings (`ENABLE_APP_SANDBOX`, `ENABLE_HARDENED_RUNTIME`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, …). The exception is `Salat-Times.entitlements`, which exists solely because App Groups have no build setting to synthesize them from; the synthesized ones are **merged into** it rather than replaced — verified, sandbox/location/network/files all survive. Inspect what actually shipped with `codesign -d --entitlements - "<path>/Salat Times.app"`. `ENABLE_USER_SELECTED_FILES` was `readonly` until the schedule window needed to *write* a CSV through `NSSavePanel`; it is `readwrite` in both configurations now, and the shipped entitlement is `com.apple.security.files.user-selected.read-write`.
- **Location has three sources, not two.** `locationMode` (`city` / `device` / `manual`) picks
  between the built-in `City` list, a CoreLocation fix, and a point the user chose by hand.
  `Services/LocationService` is the whole CoreLocation surface — one `async` call that asks for
  permission, takes a single fix and reverse-geocodes a name, plus `describe(latitude:longitude:)`
  which names a coordinate the user supplied and deliberately never touches `CLLocationManager`.
  `ENABLE_RESOURCE_ACCESS_LOCATION` must stay `YES` (it was `NO` until 2026-08-13, which made
  every location call fail silently) and the `NSLocationWhenInUseUsageDescription` Info.plist key
  is what the system prompt shows.
  Four rules hold this together:
  - **Stored coordinates are rounded to 2 decimals** (`DeviceLocation.precisionDecimals`, ~1.1 km).
    `requestFingerprint` prints coordinates to 4 decimals and *is* the cache file name, so an
    unrounded fix would mint a new month request every time GPS wobbled a few metres. A pin
    dropped on the map goes through the same rounding, for the same reason.
  - **Detection writes to `UserDefaults` and stops there.** The refetch, the notification rotation
    and the menu bar all follow from the debounced diff noticing new coordinates — same contract
    as every other setting. Nothing calls back into the manager to "apply" a location, and the
    map picker follows it too: `setManualLocation` writes and returns.
  - **The detected fix and the hand-picked pin have disjoint keys** (`LocationKeys.device` /
    `LocationKeys.manual`, both fed to the same `DeviceLocation.load/save`). Sharing one set
    would let an automatic re-detection overwrite a point the user deliberately chose, and would
    lose one of them on every switch between the modes. Both sets are in `SharedStore.ownedKeys`.
  - **Any mode with nothing valid stored falls back to the picked city** — no fix yet, no pin yet,
    a corrupt coordinate, or a `locationMode` written by a future build. `PrayerSettings.load`
    reads the city first for exactly that reason.

  **The map picker is MapKit, and MapKit is free** — part of the OS, no key, no quota, nothing
  added to a project that has no dependencies. `MapLocationPicker` wraps `MKMapView` in an
  `NSViewRepresentable` because SwiftUI's own `Map` cannot report where the user clicked until
  macOS 14 and the floor is 13; search is `MKLocalSearch`, equally keyless. Two details that look
  like bugs if undone: the click recogniser sets `delaysPrimaryMouseButtonEvents = false` or it
  swallows the presses `MKMapView` needs for panning and the map goes dead, and the map only
  re-centres on a `recenterToken` change — following the coordinate unconditionally would yank
  the map out from under a click. The two coordinate fields parse with `Double(_:)` rather than a
  `NumberFormatter`, because coordinates are typed and pasted with a dot whatever the app's
  language is.

  Detection is on demand by default, and applies to `device` mode only — a hand-picked point is
  never re-detected. `locationFollowsDevice` opts into re-detecting at launch, on
  wake and on the device's day change (`PrayerLifecycle.onDayChanged`, which exists so this does
  not also fire at all six prayers), throttled to once every 30 minutes. Crossing a border moves
  `calculationMethod` to the nearest listed city's `recommendedMethod` — the same thing picking a
  city by hand already does, and only on a country change so it never overwrites a deliberate choice.

- **CoreLocation cannot answer on every Mac, hence `Data/IPGeolocationClient`.** A Mac without GPS
  positions itself by scanning nearby Wi-Fi networks through CoreWLAN. If CoreWLAN enumerates no
  interface — a desktop on Ethernet with Wi-Fi off, or a Hackintosh whose Wi-Fi driver presents the
  card as an Ethernet device — `locationd` has *no* positioning source: it answers
  `kCLErrorLocationUnknown` (`kCLErrorDomain error 0`) and then never calls back at all. Check it
  with `CWWiFiClient.interfaceNames()`; empty means no fix will ever arrive.
  So `LocationService` falls back to resolving the public IP, through two providers because free
  ones fail (ipapi.co answered `429 RateLimited` on the first request ever made to it).
  Three things to keep:
  - **A denial is never a reason to fall back.** Someone who refused location access has not asked
    to be located by another route.
  - **The result is flagged `isApproximate`** through `DeviceLocation`, `UserDefaults` and into the
    settings window, which shows a badge and a warning line. An ISP egress measured ~75 km from the
    real position, which moved Maghrib three minutes early — invisible without the flag, and worse
    than the city the user would have picked by hand.
  - **`requestFix` uses `startUpdatingLocation`, not `requestLocation`.** The one-shot call ends the
    attempt at the first `kCLErrorLocationUnknown`, which Apple documents as *transient*; the
    timeout is what gives up now. `finishFix` is the only place updates stop, so location never
    stays running.

- **Don't put the developer's own location into code, comments, checks or logs.** Fixtures use
  unrelated cities; the location log line is `privacy: .private`, because `log show` is readable by
  anyone on the machine.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set, so every new type is `@MainActor` by default. Pure model/calculation types must be marked `nonisolated` explicitly.
- Launch-at-login uses `SMAppService.mainApp` in both `SettingsView` and `WelcomeView`.
- **Log with `Log.schedule` / `Log.notifications` / `Log.data`, not `print`.** A menu bar app has no console, so `print` is invisible once it ships. Read it back with:

```bash
log show --predicate 'subsystem == "Islam-AlorabI.Salat-Times"' --last 10m --style compact
```

  Use `.notice` or `.error` for anything you want to read back — `.info` and `.debug` are memory-only and never appear in `log show` (only in a live `log stream`).
- **Never use `Swift.Hasher` for anything persisted or compared across launches** — it is randomly seeded per process. `Core/StableHash` exists for that, and `Checks/` pins golden values so a regression fails loudly. This bit `notificationFingerprint`: every relaunch rotated all 60 identifiers and re-scheduled the entire set.
