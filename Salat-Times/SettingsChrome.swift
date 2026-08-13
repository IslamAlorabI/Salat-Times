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

    /// Icon above label, not beside it. Stacked, the item is legible at a glance and the
    /// rail can be much narrower than the 190pt a side-by-side row needed — which is width
    /// the panes get back. The label is centred and allowed two lines, because the longest
    /// of the eight languages ("Mitteilungen", "Уведомления") will not fit on one.
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: section.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(section.tint.gradient)
                    )

                Text(Translations.string(section.titleKey, language: appLanguage))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
    @ViewBuilder var content: () -> Content

    /// A flat `controlBackgroundColor` fill read as a dead grey slab. A shallow top-down
    /// gradient plus a hairline and a soft shadow is what gives the card an edge and a
    /// light source — the difference between "a coloured rectangle" and "a surface".
    private static var surface: LinearGradient {
        LinearGradient(colors: [Color(nsColor: .controlBackgroundColor),
                                Color(nsColor: .controlBackgroundColor).opacity(0.72)],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(Self.surface)
            // Clipped, not just backed: a row's hover highlight is a full-bleed rectangle,
            // so without this it spilled square over the card's rounded corners.
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.13), radius: 2.5, y: 1)

            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One line inside a card: a label on the leading edge, a control on the trailing one.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle {
                    // Both the frame *and* `multilineTextAlignment` are needed. Without
                    // the frame the label hugs its own width, so a short title and a long
                    // wrapped description ended up starting at two different edges; without
                    // the alignment the wrapped lines stay leading-aligned inside it.
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
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
