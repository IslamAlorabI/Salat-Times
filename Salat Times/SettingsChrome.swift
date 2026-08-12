import SwiftUI
import AppKit

/// Matches the host `NSWindow`'s opacity to whether the view is painting a material.
///
/// A material can only sample the desktop if the window is **not** opaque and its
/// background is clear — but a clear window also means every pixel the view does not
/// paint renders as a black hole. The settings window used to be unconditionally clear,
/// which is what produced the dark band between the sidebar and the panes: it was the
/// window showing through where nothing had drawn.
///
/// So the two have to move together, and they have to keep moving — the translucency
/// setting can change while the window is open, hence `updateNSView` and not just a
/// one-shot `onAppear`.
struct WindowOpacityConfigurator: NSViewRepresentable {
    let isTranslucent: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = !isTranslucent
        window.backgroundColor = isTranslucent ? .clear : .windowBackgroundColor
        window.hasShadow = true
    }
}

/// Paints the app's chrome background at the user's chosen translucency, and keeps the
/// window's opacity in step with it.
struct TranslucentBackground: View {
    let level: PopoverMaterial

    var body: some View {
        ZStack {
            if let material = level.material {
                Rectangle().fill(material)
            } else {
                Rectangle().fill(Color(nsColor: .windowBackgroundColor))
            }
        }
        .ignoresSafeArea()
        .background(WindowOpacityConfigurator(isTranslucent: level.material != nil))
    }
}

// The settings window's furniture.
//
// The window used to be stock `GroupBox`es stacked in a `ScrollView`, which is why it
// read as a web form rather than a Mac app: default group boxes give you a hairline and a
// bold label and nothing else, so a settings pane is a run of same-weight rectangles with
// no rhythm. These pieces give it the grouped-list shape macOS System Settings uses —
// a small uppercase section title, one filled card holding rows separated by inset
// hairlines, and an optional explanatory footnote underneath.

// MARK: - Sections

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case prayerTimes
    case appearance
    case notifications
    case about

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general:       return "general"
        case .prayerTimes:   return "prayer_times"
        case .appearance:    return "appearance"
        case .notifications: return "prayer_notifications"
        case .about:         return "about"
        }
    }

    var icon: String {
        switch self {
        case .general:       return "gearshape.fill"
        case .prayerTimes:   return "clock.fill"
        case .appearance:    return "paintbrush.fill"
        case .notifications: return "bell.fill"
        case .about:         return "info.circle.fill"
        }
    }

    /// The colour of the icon chip, as in System Settings. Purely decorative, but it is
    /// most of what makes a sidebar scannable at a glance.
    var tint: Color {
        switch self {
        case .general:       return .gray
        case .prayerTimes:   return .orange
        case .appearance:    return .purple
        case .notifications: return .red
        case .about:         return .blue
        }
    }
}

// MARK: - Sidebar

struct SettingsSidebarItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let appLanguage: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(section.tint.gradient)
                    )

                Text(Translations.string(section.titleKey, language: appLanguage))
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor
                                     : (isHovering ? Color.primary.opacity(0.07) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Cards

/// A titled group of rows. `footnote` is the small grey explanation that belongs *under*
/// a group rather than crammed into a row.
struct SettingsCard<Content: View>: View {
    var title: String? = nil
    var footnote: String? = nil
    let isRTL: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
    }
}

/// One line inside a card: a label on the leading edge, a control on the trailing one.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    let isRTL: Bool
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: isRTL ? .trailing : .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// A row whose control needs the full width underneath its label rather than beside it.
struct SettingsStackedRow<Content: View>: View {
    let title: String
    let isRTL: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: isRTL ? .trailing : .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

/// The hairline between rows, inset so it starts under the text rather than cutting the
/// card edge to edge.
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 12)
    }
}
