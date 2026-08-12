# Salat Times — macOS menu bar prayer times app

SwiftUI menu-bar-only app (`LSUIElement`) showing Islamic prayer times with a live countdown.
Single target, no dependencies, no tests.

## Build & run

```bash
xcodebuild -project "Salat Times.xcodeproj" -scheme "Salat Times" -configuration Debug build
```

- Scheme and target are both `Salat Times` (note the space — always quote paths).
- The app has **no test target** (adding one needs a one-time Xcode GUI step). Instead, the pure `Core/` types have behaviour checks that compile with `swiftc`:

```bash
./Checks/run.sh
```

  Run these after touching anything in `Salat Times/Core/`, and add a case when you fix a bug there. `./Checks/run.sh --network` additionally exercises `Data/` against the live Aladhan API and the disk cache. Everything else — notification delivery, menu bar rendering, RTL layout — still has to be checked by hand.
- Product lands in `~/Library/Developer/Xcode/DerivedData/Salat_Times-*/Build/Products/Debug/Salat Times.app`.
- `build_output.txt` at the repo root is a stale local log (git-ignored, never committed) — don't rely on it.

The project uses `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`, and the target lists
that group in `fileSystemSynchronizedGroups`, so **new `.swift` files dropped into `Salat Times/` are
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
| `Salat Times/SalatTimesApp.swift` | `@main`. `MenuBarExtra` (window style) + `settings` and `welcome` `Window` scenes. |
| `Salat Times/Core/` | Pure, `nonisolated`, I/O-free model + calculation types. No SwiftUI, no `UserDefaults` reads, no network. Shared by everything and covered by `Checks/`. |
| `Salat Times/PrayerManager.swift` | The one `ObservableObject`: fetch, countdown timer, notifications, location. Also holds `NotificationSound` and `PrayerNotificationSettings`. |
| `Salat Times/ContentView.swift` | Menu bar popover: hijri header, countdown, six prayer rows, footer. |
| `Salat Times/SettingsView.swift` | Settings window + all picker components + the `City` enum (~105 cities, line ~729) with coordinates. |
| `Salat Times/WelcomeView.swift` | First-launch onboarding, gated on `hasShownWelcome`. |
| `Salat Times/Translations.swift` | Lookup + numeral/RTL helpers. The strings themselves live in `Translations+UI/Methods/Prayer/Hijri/Settings.swift`. |

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

There is no settings-changed notification: `SettingsView` wires each control's `.onChange` directly
to `manager.loadSavedCity()`, `manager.updateCountdown()`, or `manager.schedulePrayerNotifications()`.
**A new setting needs its own `.onChange` hook or it silently won't take effect.** Language changes
are the exception — `PrayerManager.observeLanguageChanges()` watches `UserDefaults.didChangeNotification`.

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
returns.

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
- **Multi-day, within the cap.** `UNUserNotificationCenter` keeps 64 pending requests and silently
  discards the furthest-future ones past that. `horizonDays` budgets against it (6 prayers +
  reminders ≈ 5 days) and the boundary timer slides the window forward on every prayer.

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

`menuBarTitle` is `"<prayer> -<countdown>"`, recomputed every second by a `Timer` in `PrayerManager`.
`isWarningActive` flips the icon to `bell.badge.fill` when the countdown drops under `warningInterval`
minutes. The popover runs its own `TimelineView(.periodic(by: 1.0))` — the two countdowns are
computed independently and must stay in agreement.

## Notes

- Deployment target macOS 13.0, Swift 5, bundle id `Islam-AlorabI.Salat-Times`, version 3.0 (also hardcoded as `"v3.0"` in `ContentView`'s footer — update both). The *project-level* deployment target is 15.7; only the app target overrides it to 13.0.0, so any new target inherits 15.7 unless told otherwise.
- **There is no `.entitlements` file.** Entitlements are synthesized from build settings (`ENABLE_APP_SANDBOX`, `ENABLE_HARDENED_RUNTIME`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, …). Inspect what actually shipped with `codesign -d --entitlements - "<path>/Salat Times.app"`.
- `CoreLocation` is wired up but dead: `ENABLE_RESOURCE_ACCESS_LOCATION = NO` means it cannot work at all, `didUpdateLocations` just stops updates, and the city always comes from the `City` enum.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set, so every new type is `@MainActor` by default. Pure model/calculation types must be marked `nonisolated` explicitly.
- Launch-at-login uses `SMAppService.mainApp` in both `SettingsView` and `WelcomeView`.
- **Log with `Log.schedule` / `Log.notifications` / `Log.data`, not `print`.** A menu bar app has no console, so `print` is invisible once it ships. Read it back with:

```bash
log show --predicate 'subsystem == "Islam-AlorabI.Salat-Times"' --last 10m --style compact
```

  Use `.notice` or `.error` for anything you want to read back — `.info` and `.debug` are memory-only and never appear in `log show` (only in a live `log stream`).
- **Never use `Swift.Hasher` for anything persisted or compared across launches** — it is randomly seeded per process. `Core/StableHash` exists for that, and `Checks/` pins golden values so a regression fails loudly. This bit `notificationFingerprint`: every relaunch rotated all 60 identifiers and re-scheduled the entire set.
