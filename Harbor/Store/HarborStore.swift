import AppKit
import HarborKit
import Observation

/// Everything the window shows: the catalog, what's installed, and the selection.
@MainActor
@Observable
final class HarborStore {
    private(set) var apps: [CatalogApp]
    let installer = Installer()
    private(set) var installed: [String: Installed] = [:]
    private(set) var isChecking = false
    private(set) var lastChecked: Date?
    /// nil shows the shelf of all apps.
    var selection: String?

    @ObservationIgnored private var tokens: [NSObjectProtocol] = []
    private static let lastCheckedKey = "lastCatalogCheck"
    private static let checkInterval: TimeInterval = 12 * 60 * 60

    init() {
        // The copy fetched last time, unless this build of Harbor ships a newer one.
        let bundled = Catalog.bundled
        apps = (Catalog.cached.flatMap { $0.version >= bundled.version ? $0 : nil } ?? bundled).apps
        lastChecked = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date
        scanInstalled()
    }

    func start() {
        guard tokens.isEmpty else { return }
        // Re-read what's installed when Harbor comes forward or an app launches
        // or quits; nothing runs in between.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scanInstalled() }
            })
        }
        tokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scanInstalled() }
        })
        if Date().timeIntervalSince(lastChecked ?? .distantPast) > Self.checkInterval {
            Task { await checkForUpdates() }
        }
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        if let catalog = await Catalog.fetch(), catalog.version >= Catalog.bundled.version { apps = catalog.apps }
        lastChecked = Date()
        UserDefaults.standard.set(lastChecked, forKey: Self.lastCheckedKey)
        isChecking = false
        scanInstalled()
    }

    /// The apps on the shelf; Harbor's own entry only drives its self-update.
    var shelf: [CatalogApp] { apps.filter { !$0.isHub } }

    /// Harbor's catalog entry, when a newer Harbor than this one is out.
    var harborUpdate: CatalogApp? {
        guard let entry = apps.first(where: \.isHub),
              let mine = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              Version.isNewer(entry.latestVersion, than: mine) else { return nil }
        return entry
    }

    func scanInstalled() {
        var found: [String: Installed] = [:]
        for app in shelf {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else { continue }
            let version = Self.version(at: url)
            let previous = installed[app.id]
            let schema = previous?.url == url && previous?.version == version ? previous?.schema : SettingsSchema.load(fromApp: url)
            found[app.id] = Installed(url: url, version: version, schema: schema)
        }
        if found.mapValues(\.version) != installed.mapValues(\.version) || Set(found.keys) != Set(installed.keys) {
            installed = found
        }
    }

    /// Reads the version from disk every time. `Bundle(url:)` caches its Info.plist
    /// per path, so after an app is replaced in place it would still report the old one.
    static func version(at url: URL) -> String {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        return NSDictionary(contentsOf: plist)?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func status(of app: CatalogApp) -> AppStatus {
        guard let local = installed[app.id] else { return .notInstalled }
        if Version.isNewer(app.latestVersion, than: local.version) {
            return .updateAvailable(installed: local.version, latest: app.latestVersion)
        }
        return .current(local.version)
    }

    var updateCount: Int { shelf.filter { status(of: $0).isUpdate }.count }

    func icon(for app: CatalogApp) -> NSImage {
        if let url = installed[app.id]?.url { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(named: "app-\(app.id)") ?? NSWorkspace.shared.icon(for: .application)
    }

    // MARK: Actions

    /// Install and Update download the release, check it against the catalog
    /// and put it in place. Apps without a checksummed download open their site.
    func primaryAction(for app: CatalogApp) {
        switch status(of: app) {
        case .notInstalled, .updateAvailable:
            guard app.canInstall else { NSWorkspace.shared.open(app.site); return }
            Task { await install(app) }
        case .current:
            open(app)
        }
    }

    func install(_ app: CatalogApp) async {
        await installer.install(app, replacing: app.isHub ? Bundle.main.bundleURL : installed[app.id]?.url)
        scanInstalled()
    }

    /// Updates every app that has an update, one after another.
    func updateAll() async {
        for app in shelf where status(of: app).isUpdate && app.canInstall {
            await install(app)
        }
    }

    func open(_ app: CatalogApp) {
        guard let url = installed[app.id]?.url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Quits the app if it's running and opens it again, for settings that apply at launch.
    func relaunch(_ app: CatalogApp) {
        guard let url = installed[app.id]?.url else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
        guard !running.isEmpty else { open(app); return }
        var token: NSObjectProtocol?
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { note in
            let quit = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard quit?.bundleIdentifier == app.bundleID else { return }
            if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        running.forEach { $0.terminate() }
    }

    /// Handles harbor://app/<id> links from the apps' Settings menus.
    func handle(_ url: URL) {
        guard url.scheme == "harbor", url.host == "app" else { return }
        let id = url.pathComponents.dropFirst().first
        if let id, shelf.contains(where: { $0.id == id }) { selection = id }
    }

    #if DEBUG
    func injectPreview(installed: [String: Installed], selection: String?) {
        self.installed = installed
        self.selection = selection
    }
    #endif
}
