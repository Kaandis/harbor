import HarborKit
import SwiftUI

/// One app: what it is, whether it's here and current, and its settings.
struct AppDetailView: View {
    var store: HarborStore
    let app: CatalogApp
    let icons: Namespace.ID
    let back: () -> Void

    @State private var settings: AppSettings?
    private let language = AppLanguage.resolvedLocale.identifier

    init(store: HarborStore, app: CatalogApp, icons: Namespace.ID, back: @escaping () -> Void) {
        self.store = store
        self.app = app
        self.icons = icons
        self.back = back
        // Read the settings now so the page never draws a blank card first.
        _settings = State(initialValue: store.installed[app.id]?.schema.map(AppSettings.init(schema:)))
    }

    var body: some View {
        LiveScroll {
            VStack(alignment: .leading, spacing: 22) {
                Button(action: back) {
                    Label("All Apps", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut("[", modifiers: .command)

                header

                Card(title: "About") {
                    Text(app.summary.localized(language))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Link(destination: app.site) { Label("Website", systemImage: "safari") }
                        Link(destination: app.repository) { Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right") }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 4)
                }

                if let notes = app.notes {
                    Card(title: "What’s New in \(app.latestVersion)") {
                        Text(notes.localized(language))
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Card(title: "Settings") { settingsBody }

                if let permissions = settings?.permissions, !permissions.isEmpty {
                    Card(title: "Permissions") { PermissionsList(permissions: permissions) }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .task(id: store.installed[app.id]?.version) { loadSettings() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            settings?.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            Image(nsImage: store.icon(for: app))
                .resizable()
                .frame(width: 104, height: 104)
                .matchedGeometryEffect(id: "icon-\(app.id)", in: icons)
            VStack(alignment: .leading, spacing: 6) {
                Text(app.name)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(Theme.ink)
                Text(app.tagline.localized(language))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink2)
                StatusChip(status: store.status(of: app))
                    .padding(.top, 4)
            }
            Spacer(minLength: 12)
            Button { store.primaryAction(for: app) } label: { Text(primaryTitle) }
                .buttonStyle(HarborButtonStyle())
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch store.status(of: app) {
        case .notInstalled: "Get on the Website ↗"
        case .updateAvailable(_, let latest): "Update to \(latest) ↗"
        case .current: "Open"
        }
    }

    @ViewBuilder
    private var settingsBody: some View {
        if let settings {
            if settings.needsRelaunch {
                HStack {
                    Text("Restart \(app.name) to apply the change.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink2)
                    Spacer()
                    Button("Restart Now") {
                        store.relaunch(app)
                        settings.didRelaunch()
                    }
                    .buttonStyle(HarborButtonStyle(prominent: false))
                }
                .padding(.bottom, 6)
            }
            SchemaForm(settings: settings, language: language)
        } else if store.installed[app.id] == nil {
            Text("Install \(app.name) to change its settings here.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink2)
        } else {
            Text("\(app.name) doesn’t share its settings with Harbor yet. Use Settings in its menu.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func loadSettings() {
        if let schema = store.installed[app.id]?.schema {
            settings = AppSettings(schema: schema)
        } else {
            settings = nil
        }
    }
}

/// A titled cream card.
struct Card<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.hairline))
    }
}

private struct PermissionsList: View {
    let permissions: [String: Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(permissions.keys.sorted(), id: \.self) { key in
                let granted = permissions[key] ?? false
                HStack {
                    Text(name(for: key)).font(.system(size: 13.5)).foregroundStyle(Theme.ink)
                    Spacer()
                    Label(granted ? "Allowed" : "Not allowed",
                          systemImage: granted ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(granted ? Theme.ink : Theme.ink3)
                }
            }
            Text("Change these in System Settings › Privacy & Security.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func name(for key: String) -> LocalizedStringKey {
        switch key {
        case "accessibility": "Accessibility"
        case "screenRecording": "Screen Recording"
        default: LocalizedStringKey(key)
        }
    }
}
