import AppKit
import CryptoKit
import Foundation
import Observation

/// Installs and updates Harbor apps in one click.
///
/// The zip comes from the app's own GitHub release, named in the catalog
/// together with its SHA-256. A download that doesn't match is thrown away.
/// The app is quit if it's running, swapped in place (so its preferences and
/// login item stay), and opened again if it was open before.
@MainActor
@Observable
final class Installer {
    enum Phase: Equatable {
        case idle
        case downloading(Double)
        case installing
        case done
        case failed(String)

        var isBusy: Bool {
            switch self {
            case .downloading, .installing: true
            default: false
            }
        }
    }

    private(set) var phases: [String: Phase] = [:]
    /// Apps whose current or last install replaced a copy already there.
    private(set) var replacing: Set<String> = []

    func phase(of app: CatalogApp) -> Phase { phases[app.id] ?? .idle }

    /// Downloads, verifies and installs `app`, replacing the copy at
    /// `existing` or placing a new one in /Applications.
    func install(_ app: CatalogApp, replacing existing: URL?) async {
        guard !phase(of: app).isBusy else { return }
        guard let download = app.download, let expected = app.sha256?.lowercased() else {
            phases[app.id] = .failed(String(localized: "This app can’t be installed from Harbor yet."))
            return
        }
        phases[app.id] = .downloading(0)
        if existing != nil { replacing.insert(app.id) } else { replacing.remove(app.id) }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent("Harbor-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: work) }

        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let zip = work.appendingPathComponent("\(app.name).zip")
            let data = try await fetch(download) { [weak self] fraction in
                self?.phases[app.id] = .downloading(fraction)
            }
            guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == expected else {
                throw InstallError.checksum
            }
            try data.write(to: zip)

            phases[app.id] = .installing
            let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
            try await run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path])
            guard let newApp = try FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }),
                  Bundle(url: newApp)?.bundleIdentifier == app.bundleID else { throw InstallError.wrongApp }

            let isSelf = app.bundleID == Bundle.main.bundleIdentifier
            let target = existing ?? URL(fileURLWithPath: "/Applications").appendingPathComponent("\(app.name).app")
            let wasRunning = !isSelf && !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
            if wasRunning { try await quit(app.bundleID) }

            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: newApp)
            } else {
                try FileManager.default.moveItem(at: newApp, to: target)
            }
            // Tell Launch Services about the new copy so lookups see it right away.
            LSRegisterURL(target as CFURL, true)
            phases[app.id] = .done
            // "Updated" shows for a moment, then the app is simply current.
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if phases[app.id] == .done { phases[app.id] = nil }
            }

            if isSelf {
                relaunchSelf(at: target)
            } else if wasRunning || existing == nil {
                _ = try? await NSWorkspace.shared.openApplication(at: target, configuration: NSWorkspace.OpenConfiguration())
            }
        } catch let error as InstallError {
            phases[app.id] = .failed(error.message)
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            phases[app.id] = .failed(InstallError.noPermission.message)
        } catch {
            phases[app.id] = .failed(error.localizedDescription)
        }
    }

    func reset(_ app: CatalogApp) { phases[app.id] = nil }

    #if DEBUG
    func setPreview(_ phase: Phase, for id: String, replacing: Bool = false) {
        phases[id] = phase
        if replacing { self.replacing.insert(id) } else if case .downloading(0) = phase { self.replacing.remove(id) }
    }
    #endif

    // MARK: Steps

    /// Streams the download so the button can show real progress.
    private func fetch(_ url: URL, progress: @escaping (Double) -> Void) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("Harbor", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw InstallError.download }
        let expected = max(response.expectedContentLength, 1)
        var data = Data()
        data.reserveCapacity(Int(max(expected, 0)))
        var lastReport = 0
        for try await byte in bytes {
            data.append(byte)
            if data.count - lastReport >= 64 * 1024 {
                lastReport = data.count
                progress(min(1, Double(data.count) / Double(expected)))
            }
        }
        progress(1)
        return data
    }

    private func run(_ tool: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in continuation.resume() }
        }
        guard process.terminationStatus == 0 else { throw InstallError.unpack }
    }

    /// Asks the app to quit and waits up to ten seconds for it to go.
    private func quit(_ bundleID: String) async throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        running.forEach { $0.terminate() }
        for _ in 0..<50 where running.contains(where: { !$0.isTerminated }) {
            try await Task.sleep(for: .milliseconds(200))
        }
        if running.contains(where: { !$0.isTerminated }) { throw InstallError.stillRunning }
    }

    /// Harbor replaced its own bundle: open the new copy once this one has quit.
    private func relaunchSelf(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", url.path]
        try? process.run()
        NSApp.terminate(nil)
    }
}

private enum InstallError: Error {
    case download, checksum, unpack, wrongApp, stillRunning, noPermission

    var message: String {
        switch self {
        case .download: String(localized: "The download didn’t finish. Check your connection and try again.")
        case .checksum: String(localized: "The download doesn’t match the catalog, so it wasn’t installed.")
        case .unpack: String(localized: "The download couldn’t be unpacked.")
        case .wrongApp: String(localized: "The download contained a different app, so it wasn’t installed.")
        case .stillRunning: String(localized: "The app didn’t quit. Quit it and try again.")
        case .noPermission: String(localized: "Harbor can’t write to the app’s folder. Update it from its website instead.")
        }
    }
}
