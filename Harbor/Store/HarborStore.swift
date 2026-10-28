import AppKit
import HarborKit
import Observation

/// Everything the window shows: the catalog, what's installed, and the selection.
@MainActor
@Observable
final class HarborStore {
    private(set) var apps: [CatalogApp]
    private(set) var installed: [String: Installed] = [:]
    private(set) var isChecking = false
    private(set) var lastChecked: Date?
    /// nil shows the shelf of all apps.
    var selection: String?

    @ObservationIgnored private var tokens: [NSObjectProtocol] = []
    private static let lastCheckedKey = "lastCatalogCheck"
    private static let checkInterval: TimeInterval = 12 * 60 * 60

    init() {
        apps = (Catalog.cached ?? Catalog.bundled).apps
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
        if let catalog = await Catalog.fetch() { apps = catalog.apps }
        lastChecked = Date()
        UserDefaults.standard.set(lastChecked, forKey: Self.lastCheckedKey)
        isChecking = false
        scanInstalled()
    }

    func scanInstalled() {
        var found: [String: Installed] = [:]
        for app in apps {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID),
                  let bundle = Bundle(url: url) else { continue }
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            let previous = installed[app.id]
            let schema = previous?.url == url && previous?.version == version ? previous?.schema : SettingsSchema.load(fromApp: url)
            found[app.id] = Installed(url: url, version: version, schema: schema)
        }
        if found.mapValues(\.version) != installed.mapValues(\.version) || Set(found.keys) != Set(installed.keys) {
            installed = found
        }
    }

    func status(of app: CatalogApp) -> AppStatus {
        guard let local = installed[app.id] else { return .notInstalled }
        if Version.isNewer(app.latestVersion, than: local.version) {
            return .updateAvailable(installed: local.version, latest: app.latestVersion)
        }
        return .current(local.version)
    }

    var updateCount: Int { apps.filter { status(of: $0).isUpdate }.count }

    func icon(for app: CatalogApp) -> NSImage {
        if let url = installed[app.id]?.url { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(named: "app-\(app.id)") ?? NSWorkspace.shared.icon(for: .application)
    }

    // MARK: Actions

    /// Get and Update open the app's website; Harbor never downloads anything itself.
    func primaryAction(for app: CatalogApp) {
        switch status(of: app) {
        case .notInstalled, .updateAvailable: NSWorkspace.shared.open(app.site)
        case .current: open(app)
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
        if let id, apps.contains(where: { $0.id == id }) { selection = id }
    }

    #if DEBUG
    func injectPreview(installed: [String: Installed], selection: String?) {
        self.installed = installed
        self.selection = selection
    }
    #endif
}
