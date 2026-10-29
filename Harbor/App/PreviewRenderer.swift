#if DEBUG
import AppKit
import HarborKit
import SwiftUI

/// `Harbor --render-previews <dir> [--ferry-app <path>]` writes PNGs of the
/// harbour in several states and exits. ImageRenderer greys out the turned
/// hull layers, so for the harbour itself `--demo` and a window capture are
/// the better check., for checking the UI without clicking
/// through it. With --ferry-app, Ferry's page shows that build's real schema.
@MainActor
enum PreviewRenderer {
    static func runIfRequested() {
        let args = CommandLine.arguments
        // `Harbor --install-test <app id> <path/to/App.app>` installs that app
        // from the catalog over the given copy, logs the result and exits.
        if let i = args.firstIndex(of: "--install-test"), i + 2 < args.count {
            let store = HarborStore()
            let target = URL(fileURLWithPath: args[i + 2])
            guard let app = store.apps.first(where: { $0.id == args[i + 1] }) else { exit(2) }
            Task {
                await store.installer.install(app, replacing: target)
                let phase = store.installer.phase(of: app)
                let version = HarborStore.version(at: target)
                print("install-test \(app.id): \(phase) → version \(version)")
                exit(phase == .done ? 0 : 1)
            }
            return
        }
        // `Harbor --uninstall-test <path/to/Test.app>` uninstalls a stand-in app
        // with the bundle id app.harbor.UninstallTest, logs and exits.
        if let i = args.firstIndex(of: "--uninstall-test"), i + 1 < args.count {
            let json = """
            {"id":"uninstall-test","name":"HarborUninstallTest","bundleID":"app.harbor.UninstallTest",
             "tagline":{"en":""},"summary":{"en":""},"site":"https://example.com","repository":"https://example.com",
             "latestVersion":"1.0","minimumMacOS":"15.0"}
            """
            guard let app = try? JSONDecoder().decode(CatalogApp.self, from: Data(json.utf8)) else { exit(2) }
            let uninstaller = Uninstaller()
            print("leftovers: \(Uninstaller.leftovers(of: app).map(\.path))")
            Task {
                await uninstaller.uninstall(app, at: URL(fileURLWithPath: args[i + 1]))
                print("uninstall-test: \(uninstaller.phase(of: app))")
                exit(uninstaller.phase(of: app) == .idle ? 0 : 1)
            }
            return
        }
        guard let i = args.firstIndex(of: "--render-previews"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var ferry: Installed?
        if let j = args.firstIndex(of: "--ferry-app"), j + 1 < args.count {
            let url = URL(fileURLWithPath: args[j + 1])
            ferry = Installed(url: url, version: "1.2.1", schema: SettingsSchema.load(fromApp: url))
        }

        struct Frame: View {
            let store: HarborStore
            var body: some View {
                ContentView(store: store)
                    .frame(width: 1000, height: 720)
                    .background(Theme.background)
            }
        }
        func scene(_ name: String, installed: [String: Installed], selection: String? = nil,
                   phases: [String: Installer.Phase] = [:], dark: Bool = false) {
            let store = HarborStore()
            store.injectPreview(installed: installed, selection: selection)
            phases.forEach { store.installer.setPreview($1, for: $0) }
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            write(Frame(store: store).environment(\.colorScheme, dark ? .dark : .light), name: name, to: dir)
        }
        let both = ["ferry": ferry, "inlet": ferry.map { _ in Installed(url: URL(fileURLWithPath: "/Applications/Inlet.app"), version: "1.4", schema: nil) }]
            .compactMapValues { $0 }
        scene("1-harbour", installed: both)
        scene("2-anchor", installed: ferry.map { ["ferry": $0] } ?? [:])
        scene("3-sailing", installed: ferry.map { ["ferry": $0] } ?? [:], phases: ["inlet": .downloading(0.55)])
        if let ferry {
            let old = Installed(url: ferry.url, version: "1.1", schema: ferry.schema)
            scene("4-supply", installed: ["ferry": old], phases: ["ferry": .downloading(0.6)])
        }
        scene("5-ferry-page", installed: both, selection: "ferry")
        scene("6-office", installed: both, selection: HarborStore.officeID)
        scene("7-night", installed: both, dark: true)
        scene("8-night-page", installed: both, selection: "ferry", dark: true)
        exit(0)
    }

    private static func write(_ view: some View, name: String, to dir: URL) {
        let renderer = ImageRenderer(content: view.environment(\.locale, AppLanguage.resolvedLocale).environment(\.isStaticRender, true))
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}
#endif
