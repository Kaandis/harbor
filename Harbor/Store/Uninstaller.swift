import AppKit
import Foundation
import Observation

/// Removes a Harbor app and everything it left on the Mac: its settings,
/// caches, saved windows, logs, support files and sandbox container, and
/// the permissions macOS granted it. Files go to the Trash rather than
/// vanishing, so a slip can still be undone from there.
@MainActor
@Observable
final class Uninstaller {
    enum Phase: Equatable {
        case idle
        case working
        case failed(String)
    }

    private(set) var phases: [String: Phase] = [:]

    func phase(of app: CatalogApp) -> Phase { phases[app.id] ?? .idle }

    /// What uninstalling would move to the Trash besides the app itself.
    static func leftovers(of app: CatalogApp) -> [URL] {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        let id = app.bundleID
        var paths = [
            "Preferences/\(id).plist",
            "Application Support/\(id)",
            "Caches/\(id)",
            "HTTPStorages/\(id)",
            "HTTPStorages/\(id).binarycookies",
            "WebKit/\(id)",
            "Cookies/\(id).binarycookies",
            "Saved Application State/\(id).savedState",
            "Containers/\(id)",
            "LaunchAgents/\(id).plist",
            "Logs/\(id)",
            // Harbor apps name their log and support folders after themselves.
            "Logs/\(app.name)",
            "Application Support/\(app.name)",
        ]
        let byHost = library.appendingPathComponent("Preferences/ByHost", isDirectory: true)
        if let hosts = try? fm.contentsOfDirectory(atPath: byHost.path) {
            paths += hosts.filter { $0.hasPrefix(id + ".") }.map { "Preferences/ByHost/\($0)" }
        }
        return paths.map { library.appendingPathComponent($0) }.filter { fm.fileExists(atPath: $0.path) }
    }

    /// Quits the app, forgets its settings and permissions, and moves the
    /// app and its files to the Trash.
    func uninstall(_ app: CatalogApp, at url: URL) async {
        guard phase(of: app) != .working else { return }
        phases[app.id] = .working
        do {
            try await quit(app.bundleID)
            // Through `defaults` so the preferences cache lets go too;
            // trashing the plist alone would leave the values in memory.
            await run("/usr/bin/defaults", ["delete", app.bundleID])
            await run("/usr/bin/tccutil", ["reset", "All", app.bundleID])
            for item in Self.leftovers(of: app) {
                try? FileManager.default.trashItem(at: item, resultingItemURL: nil)
            }
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            phases[app.id] = nil
        } catch UninstallError.stillRunning {
            phases[app.id] = .failed(String(localized: "\(app.name) didn’t quit. Quit it and try again."))
        } catch {
            phases[app.id] = .failed(String(localized: "Harbor couldn’t move \(app.name) to the Trash. Drag it there from Applications instead."))
        }
    }

    func reset(_ app: CatalogApp) { phases[app.id] = nil }

    private func quit(_ bundleID: String) async throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        running.forEach { $0.terminate() }
        for _ in 0..<50 where running.contains(where: { !$0.isTerminated }) {
            try await Task.sleep(for: .milliseconds(200))
        }
        if running.contains(where: { !$0.isTerminated }) { throw UninstallError.stillRunning }
    }

    /// Runs a tool and waits; these steps are best effort, so failures pass.
    private func run(_ tool: String, _ arguments: [String]) async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in continuation.resume() }
        }
    }
}

private enum UninstallError: Error {
    case stillRunning
}
