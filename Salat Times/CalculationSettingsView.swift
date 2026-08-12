import SwiftUI

// The calculation axes beyond `method`, plus the per-prayer corrections.
//
// Split out of `SettingsView` because that file is already the settings window *and*
// six picker components. Nothing here calls into `PrayerManager`: every control just
// writes a preference, and the manager's debounced `UserDefaults` diff decides what
// that implies. Adding a control to these sections needs no wiring at all — only that
// the key it writes is one `PrayerSettings.load()` reads.
//
// The split that matters is which side of `requestFingerprint` a setting falls on:
//
//  - Madhab, high-latitude rule and midnight mode change what the *server* computes,
//    so changing one refetches the month.
//  - Tuning and the fixed offsets are applied on read by `PrayerAdjustments`, so they
//    move the times immediately and never touch the network.

// MARK: - Madhab / high latitude / midnight mode

struct CalculationOptionsSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("asrSchool") private var school = 0
    @AppStorage("latitudeAdjustment") private var latitudeAdjustment = 0
    @AppStorage("midnightMode") private var midnightMode = 0

    /// Aladhan's `latitudeAdjustmentMethod`. `0` is a real value (NONE) — verified
    /// against the API, which echoes it back in `meta` — not an "unset" sentinel.
    private let latitudeRules: [(value: Int, key: String)] = [
        (0, "latitude_none"),
        (1, "latitude_middle_night"),
        (2, "latitude_one_seventh"),
        (3, "latitude_angle_based"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: alignment, spacing: 6) {
                HStack(spacing: 0) {
                    TimeFormatRadioButton(title: Translations.string("madhab_shafii", language: appLanguage),
                                          isSelected: school == 0) { school = 0 }

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)

                    TimeFormatRadioButton(title: Translations.string("madhab_hanafi", language: appLanguage),
                                          isSelected: school == 1) { school = 1 }
                }
                hint("asr_madhab_hint")
            }

            Divider()

            VStack(alignment: alignment, spacing: 6) {
                HStack {
                    Text(Translations.string("high_latitude", language: appLanguage))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $latitudeAdjustment) {
                        ForEach(latitudeRules, id: \.value) { rule in
                            Text(Translations.string(rule.key, language: appLanguage)).tag(rule.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
                hint("high_latitude_hint")
            }

            Divider()

            VStack(alignment: alignment, spacing: 6) {
                HStack {
                    Text(Translations.string("midnight_mode", language: appLanguage))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $midnightMode) {
                        Text(Translations.string("midnight_standard", language: appLanguage)).tag(0)
                        Text(Translations.string("midnight_jafari", language: appLanguage)).tag(1)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
                hint("midnight_mode_hint")
            }
        }
        .padding(.vertical, 4)
    }

    private var alignment: HorizontalAlignment {
        Translations.isRTL(appLanguage) ? .trailing : .leading
    }

    private func hint(_ key: String) -> some View {
        Text(Translations.string(key, language: appLanguage))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: Translations.isRTL(appLanguage) ? .trailing : .leading)
    }
}

// MARK: - Per-prayer tuning

struct PrayerTuningSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("numberFormat") private var numberFormat = "western"

    @AppStorage("tune_Fajr") private var fajr = 0
    @AppStorage("tune_Sunrise") private var sunrise = 0
    @AppStorage("tune_Dhuhr") private var dhuhr = 0
    @AppStorage("tune_Asr") private var asr = 0
    @AppStorage("tune_Maghrib") private var maghrib = 0
    @AppStorage("tune_Isha") private var isha = 0

    /// The shared value behind "apply to all". Seeded from the prayers themselves so it
    /// opens showing the current offset when they already agree.
    @State private var allValue = 0

    private var rows: [(key: PrayerKey, binding: Binding<Int>)] {
        [(.fajr, $fajr), (.sunrise, $sunrise), (.dhuhr, $dhuhr),
         (.asr, $asr), (.maghrib, $maghrib), (.isha, $isha)]
    }

    private var isPristine: Bool {
        rows.allSatisfy { $0.binding.wrappedValue == 0 }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.key) { row in
                TuneRow(name: Translations.string(row.key.translationKey(isFriday: false), language: appLanguage),
                        icon: row.key.systemImageName,
                        value: row.binding,
                        appLanguage: appLanguage,
                        numberFormat: numberFormat)
            }

            Divider()

            HStack(spacing: 12) {
                Text(Translations.string("apply_to_all", language: appLanguage))
                    .font(.system(size: 13, weight: .medium))

                Stepper(value: $allValue, in: PrayerAdjustments.tuneRange) {
                    Text(SettingsFormat.signedMinutes(allValue, language: appLanguage, numberFormat: numberFormat))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 74, alignment: .leading)
                }
                .onChange(of: allValue) { newValue in
                    for row in rows { row.binding.wrappedValue = newValue }
                }

                Spacer()

                Button(Translations.string("reset", language: appLanguage)) {
                    allValue = 0
                    for row in rows { row.binding.wrappedValue = 0 }
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .disabled(isPristine && allValue == 0)
            }

            Text(Translations.string("prayer_tuning_hint", language: appLanguage))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: Translations.isRTL(appLanguage) ? .trailing : .leading)
        }
        .padding(.vertical, 4)
        .onAppear {
            let values = Set(rows.map { $0.binding.wrappedValue })
            allValue = values.count == 1 ? (values.first ?? 0) : 0
        }
    }
}

private struct TuneRow: View {
    let name: String
    let icon: String
    @Binding var value: Int
    let appLanguage: String
    let numberFormat: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(value == 0 ? .secondary : .accentColor)
                .frame(width: 22)

            Text(name)
                .font(.system(size: 13))
                .frame(width: 80, alignment: Translations.isRTL(appLanguage) ? .trailing : .leading)

            Spacer()

            Stepper(value: $value, in: PrayerAdjustments.tuneRange) {
                Text(SettingsFormat.signedMinutes(value, language: appLanguage, numberFormat: numberFormat))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(value == 0 ? .secondary : .primary)
                    .frame(width: 74, alignment: .leading)
            }
        }
    }
}

// MARK: - Fixed Fajr / Isha offsets

struct FixedOffsetsSection: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"
    @AppStorage("numberFormat") private var numberFormat = "western"
    @AppStorage("fajrBeforeSunriseMinutes") private var fajrBeforeSunrise = 0
    @AppStorage("ishaAfterMaghribMinutes") private var ishaAfterMaghrib = 0

    var body: some View {
        VStack(spacing: 10) {
            OffsetRow(label: Translations.string("fajr_before_sunrise", language: appLanguage),
                      icon: "sunrise",
                      minutes: $fajrBeforeSunrise,
                      appLanguage: appLanguage,
                      numberFormat: numberFormat)

            Divider()

            OffsetRow(label: Translations.string("isha_after_maghrib", language: appLanguage),
                      icon: "moon.stars.fill",
                      minutes: $ishaAfterMaghrib,
                      appLanguage: appLanguage,
                      numberFormat: numberFormat)

            Text(Translations.string("fixed_times_hint", language: appLanguage))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: Translations.isRTL(appLanguage) ? .trailing : .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct OffsetRow: View {
    let label: String
    let icon: String
    /// `0` means off; anything else is clamped into `PrayerSettings.fixedOffsetRange`.
    @Binding var minutes: Int
    let appLanguage: String
    let numberFormat: String

    /// Switching on lands on 90 minutes rather than the range's floor — 15 minutes
    /// before sunrise is not a Fajr anybody wants as a starting point.
    private static let defaultMinutes = 90

    private var isOn: Binding<Bool> {
        Binding(get: { minutes > 0 },
                set: { minutes = $0 ? Self.defaultMinutes : 0 })
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(minutes > 0 ? .accentColor : .secondary)
                .frame(width: 22)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(minutes > 0 ? .primary : .secondary)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()

            Spacer()

            if minutes > 0 {
                Stepper(value: $minutes, in: PrayerSettings.fixedOffsetRange, step: 5) {
                    Text(SettingsFormat.minutes(minutes, language: appLanguage, numberFormat: numberFormat))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 74, alignment: .leading)
                }
            } else {
                Text(Translations.string("off", language: appLanguage))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Shared formatting

enum SettingsFormat {
    /// `+5 min` / `0 min`, in the user's numerals.
    static func signedMinutes(_ value: Int, language: String, numberFormat: String) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        let digits = Translations.localizedNumber("\(abs(value))", numberFormat: numberFormat)
        return "\(sign)\(digits) \(Translations.string("minutes_unit", language: language))"
    }

    static func minutes(_ value: Int, language: String, numberFormat: String) -> String {
        let digits = Translations.localizedNumber("\(value)", numberFormat: numberFormat)
        return "\(digits) \(Translations.string("minutes_unit", language: language))"
    }
}
