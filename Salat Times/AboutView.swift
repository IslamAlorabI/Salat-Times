import SwiftUI
import AppKit

/// The About pane.
///
/// Version and build are read from the bundle, never typed in. The footer used to carry a
/// hardcoded `"v3.0"` string that had to be edited in lockstep with the project's
/// `MARKETING_VERSION` — and predictably drifted.
struct AboutView: View {
    @AppStorage("appLanguage") private var appLanguage = "ar"

    private var isRTL: Bool { Translations.isRTL(appLanguage) }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// From the bundle rather than a literal, so it cannot drift from the deployment
    /// target the way a typed-in "13.0" would. Xcode synthesises it as `13.0.0`; the
    /// trailing patch component is noise on a version line, so it is dropped when zero.
    private static var minimumSystem: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String ?? "13.0"
        let parts = raw.split(separator: ".")
        if parts.count == 3, parts[2] == "0" {
            return parts.dropLast().joined(separator: ".")
        }
        return raw
    }

    private static var copyrightYear: String {
        "\(Calendar.current.component(.year, from: Date()))"
    }

    /// Version strings, URLs and the like are Latin-script and must stay left-to-right
    /// even in an Arabic window — otherwise `3.0 (30)` renders with its parentheses
    /// mirrored and the digits reordered.
    private func value(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .environment(\.layoutDirection, .leftToRight)
    }

    var body: some View {
        VStack(spacing: 18) {
            identity

            SettingsCard(title: Translations.string("about_details", language: appLanguage), isRTL: isRTL) {
                // Never run through `Translations.localizedNumber`. A version is an
                // *identifier*, not a quantity: "٣.٠ (٣٠)" is not a build anyone can
                // quote in a bug report, and no installer, changelog or release page
                // writes it that way. Same for the macOS requirement.
                SettingsRow(title: Translations.string("about_version", language: appLanguage), isRTL: isRTL) {
                    value("\(Self.version) (\(Self.build))")
                        .textSelection(.enabled)
                }
                SettingsDivider()
                SettingsRow(title: Translations.string("about_requires", language: appLanguage), isRTL: isRTL) {
                    value("macOS \(Self.minimumSystem)")
                }
            }

            SettingsCard(title: Translations.string("about_links", language: appLanguage),
                         footnote: Translations.string("about_data_note", language: appLanguage),
                         isRTL: isRTL) {
                AboutLinkRow(title: Translations.string("about_data_source", language: appLanguage),
                             subtitle: "aladhan.com",
                             url: "https://aladhan.com",
                             isRTL: isRTL)
                SettingsDivider()
                AboutLinkRow(title: Translations.string("about_developer", language: appLanguage),
                             subtitle: "github.com/IslamAlorabI",
                             url: "https://github.com/IslamAlorabI",
                             isRTL: isRTL)
            }

            Text("© \(Self.copyrightYear) Islam AlorabI")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .environment(\.layoutDirection, .leftToRight)

            Spacer(minLength: 0)
        }
    }

    private var identity: some View {
        VStack(spacing: 8) {
            // The real bundle icon, so this pane can never disagree with what Finder shows.
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            Text(Translations.string("app_name", language: appLanguage))
                .font(.system(size: 19, weight: .semibold))

            Text(Translations.string("about_tagline", language: appLanguage))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

}

/// A link as a whole clickable row, rather than a label with a small button parked at the
/// far edge.
///
/// The button version crowded badly in Arabic: the title and URL are right-aligned while
/// the button stayed pinned to the left edge, so the row read as two disconnected halves
/// with a gap down the middle, and `arrow.up.forward.square` rendered as a hard little box
/// rather than an affordance. The whole row is now the target, it highlights on hover, and
/// the glyph is a plain arrow that follows the text.
private struct AboutLinkRow: View {
    let title: String
    let subtitle: String
    let url: String
    let isRTL: Bool

    @State private var isHovering = false

    var body: some View {
        Button {
            if let link = URL(string: url) { NSWorkspace.shared.open(link) }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: isRTL ? .trailing : .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(isHovering ? Color.accentColor : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isHovering ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(isHovering ? Color.primary.opacity(0.05) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(url)
    }
}
