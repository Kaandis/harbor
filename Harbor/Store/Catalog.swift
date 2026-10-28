import AppKit
import Foundation
import HarborKit

/// The list of Harbor apps. A copy ships inside Harbor; a fresher one is
/// published with the website and fetched at most twice a day. That fetch is
/// the only time Harbor uses the network.
struct Catalog: Decodable {
    let version: Int
    let apps: [CatalogApp]

    static let remote = URL(string: "https://kaandis.github.io/harbor/catalog.json")!

    static var bundled: Catalog {
        let url = Bundle.main.url(forResource: "catalog", withExtension: "json")!
        // The bundled file is part of the app; failing to read it is a build mistake.
        return try! JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    /// The last catalog fetched from the website, kept between launches.
    static var cacheURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Harbor", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("catalog.json")
    }

    static var cached: Catalog? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }

    /// Downloads the published catalog. Returns nil when offline or not published yet.
    static func fetch() async -> Catalog? {
        var request = URLRequest(url: remote, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Harbor", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return nil }
        try? data.write(to: cacheURL, options: .atomic)
        return catalog
    }
}

struct CatalogApp: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let tagline: SettingsSchema.Text
    let summary: SettingsSchema.Text
    let site: URL
    let repository: URL
    let latestVersion: String
    let minimumMacOS: String
    let notes: SettingsSchema.Text?

    static func == (a: CatalogApp, b: CatalogApp) -> Bool { a.id == b.id && a.latestVersion == b.latestVersion }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// What Harbor knows about an app on this Mac.
struct Installed {
    let url: URL
    let version: String
    let schema: SettingsSchema?
}

/// Where an app stands, which decides the main button.
enum AppStatus: Equatable {
    case notInstalled
    case updateAvailable(installed: String, latest: String)
    case current(String)

    var isUpdate: Bool {
        if case .updateAvailable = self { return true }
        return false
    }
}

enum Version {
    /// Compares dotted version strings numerically ("1.10" is newer than "1.9").
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
