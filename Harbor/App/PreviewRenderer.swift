#if DEBUG
import AppKit
import HarborKit
import SwiftUI

/// `Harbor --render-previews <dir> [--ferry-app <path>]` writes PNGs of the
/// shelf and an app page and exits, for checking the UI without clicking
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
        guard let i = args.firstIndex(of: "--render-previews"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let store = HarborStore()
        var installed: [String: Installed] = [:]
        if let j = args.firstIndex(of: "--ferry-app"), j + 1 < args.count {
            let url = URL(fileURLWithPath: args[j + 1])
            installed["ferry"] = Installed(url: url, version: "1.0", schema: SettingsSchema.load(fromApp: url))
        }
        store.injectPreview(installed: installed, selection: nil)

        struct Frame<Content: View>: View {
            @Namespace var icons
            let content: (Namespace.ID) -> Content
            var body: some View {
                content(icons)
                    .frame(width: 900, height: 1300, alignment: .top)
                    .background(Theme.background)
            }
        }
        write(Frame { ShelfView(store: store, icons: $0, open: { _ in }) }, name: "1-shelf", to: dir)
        if let ferry = store.shelf.first(where: { $0.id == "ferry" }) {
            write(Frame { AppDetailView(store: store, app: ferry, icons: $0, back: {}) }, name: "2-ferry", to: dir)
        }
        if let inlet = store.shelf.first(where: { $0.id == "inlet" }) {
            write(Frame { AppDetailView(store: store, app: inlet, icons: $0, back: {}) }, name: "3-inlet", to: dir)
        }
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
