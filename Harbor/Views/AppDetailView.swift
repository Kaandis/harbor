import HarborKit
import SwiftUI

/// One app: what it is, whether it's here and current, and its settings.
struct AppDetailView: View {
    var store: HarborStore
    let app: CatalogApp
    let icons: Namespace.ID
    var inset: CGFloat = 0
    var onScroll: (CGFloat) -> Void = { _ in }
    let back: () -> Void

    @State private var settings: AppSettings?
    private let language = AppLanguage.resolvedLocale.identifier

    init(store: HarborStore, app: CatalogApp, icons: Namespace.ID, inset: CGFloat = 0,
         onScroll: @escaping (CGFloat) -> Void = { _ in }, back: @escaping () -> Void) {
        self.store = store
        self.app = app
        self.icons = icons
        self.inset = inset
        self.onScroll = onScroll
        self.back = back
        // Read the settings now so the page never draws a blank card first.
        _settings = State(initialValue: store.installed[app.id]?.schema.map(AppSettings.init(schema:)))
    }

    var body: some View {
        LiveScroll(inset: inset, onScroll: onScroll) {
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
                    Link(destination: app.site) { Label("Website", systemImage: "safari") }
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

                if store.installed[app.id] != nil {
                    UninstallCard(store: store, app: app, done: back)
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
            InstallButton(store: store, app: app)
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
            if let url = store.installed[app.id]?.url, let own = OwnSettings.load(fromApp: url) {
                // Some settings are too rich to draw from a schema; the app
                // opens its own window for those.
                Divider().overlay(Theme.hairline).padding(.top, 4)
                Button {
                    own.open(app: url, bundleID: app.bundleID)
                } label: {
                    Label(own.title.localized(language), systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(HarborButtonStyle(prominent: false))
                .padding(.top, 12)
            }
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

/// The last card on an installed app's page: remove it and everything it
/// keeps on this Mac, after one confirmation.
private struct UninstallCard: View {
    var store: HarborStore
    let app: CatalogApp
    /// Back to the harbour, to watch the boat leave.
    let done: () -> Void

    @State private var confirming = false
    @State private var showingFiles = false

    var body: some View {
        let leftovers = Uninstaller.leftovers(of: app)
        let phase = store.uninstaller.phase(of: app)
        Card(title: "Uninstall") {
            Text("Removes \(app.name) and everything it keeps on this Mac: its settings, caches and logs, and the permissions you gave it. It all goes to the Trash, so you can still change your mind.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if !leftovers.isEmpty {
                DisclosureGroup(isExpanded: $showingFiles) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(leftovers, id: \.self) { url in
                            Text(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(.system(size: 11.5).monospaced())
                                .foregroundStyle(Theme.ink2)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("\(leftovers.count + 1) items, the app included")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
            }
            HStack(spacing: 12) {
                Button {
                    confirming = true
                } label: {
                    Text(phase == .working ? "Removing…" : "Uninstall \(app.name)…")
                }
                .buttonStyle(HarborButtonStyle(prominent: false))
                .foregroundStyle(Theme.coral)
                .disabled(phase == .working)
                if case .failed(let message) = phase {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(.top, 4)
        }
        .confirmationDialog("Uninstall \(app.name)?", isPresented: $confirming) {
            Button("Move to Trash", role: .destructive) {
                Task {
                    await store.uninstall(app)
                    if store.installed[app.id] == nil { done() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(app.name) quits, and it and its files go to the Trash. Its permissions are reset, so reinstalling it will ask for them again.")
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

/// Installed, an update waiting, or not here yet.
struct StatusChip: View {
    let status: AppStatus

    var body: some View {
        Group {
            switch status {
            case .current(let version):
                Label { Text("Installed · \(version)") } icon: { Image(systemName: "checkmark") }
                    .foregroundStyle(Theme.ink2)
                    .background(Capsule().fill(Theme.raised).padding(-1))
            case .updateAvailable(_, let latest):
                Label { Text("Update · \(latest)") } icon: { Image(systemName: "arrow.down") }
                    .foregroundStyle(Theme.background)
                    .background(Capsule().fill(Theme.ink).padding(-1))
            case .notInstalled:
                Label { Text("Not installed") } icon: { Image(systemName: "plus") }
                    .foregroundStyle(Theme.ink2)
                    .background(Capsule().strokeBorder(Theme.hairline, lineWidth: 1.5).padding(-1))
            }
        }
        .font(.system(size: 11.5, weight: .semibold))
        .labelStyle(ChipLabelStyle())
    }
}

private struct ChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 9, weight: .bold))
            configuration.title
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
    }
}

/// An app's own settings window, for what a schema can't draw: declared as
/// `app.ownSettings` in its settings-schema.json, with a button title and the
/// section to open.
struct OwnSettings: Decodable {
    let title: SettingsSchema.Text
    let section: String

    private struct File: Decodable {
        struct App: Decodable { let ownSettings: OwnSettings? }
        let app: App
    }

    static func load(fromApp url: URL) -> OwnSettings? {
        let file = url.appendingPathComponent("Contents/Resources/settings-schema.json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return (try? JSONDecoder().decode(File.self, from: data))?.app.ownSettings
    }

    /// Asks the app to open its window at `section`; launches it first if
    /// it isn't running.
    func open(app url: URL, bundleID: String) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--open-settings", section]
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } else {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("app.harbor.openOwnSettings"), object: bundleID,
                userInfo: ["section": section], deliverImmediately: true)
        }
    }
}
