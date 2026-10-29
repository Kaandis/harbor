#if DEBUG
import AppKit

/// `Harbor --demo` plays an install and an update with fake progress, so the
/// harbour's voyages can be watched and checked without touching real apps:
/// Inlet sails in from anchor, then a supply boat brings Ferry an update.
/// `--select <id>` opens a page, `--dark` shows the harbour at night and
/// `--fleet <n>` adds stand-in apps to fill more berths; `--window 1400x980`
/// sizes the window for site screenshots.
@MainActor
enum DemoDriver {
    static func runIfRequested(_ store: HarborStore) {
        let args = CommandLine.arguments
        if args.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if let i = args.firstIndex(of: "--select"), i + 1 < args.count { store.selection = args[i + 1] }
        if let i = args.firstIndex(of: "--fleet"), i + 1 < args.count, let n = Int(args[i + 1]) { store.addFleetForDemo(n) }
        if let i = args.firstIndex(of: "--window"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: "x").compactMap { Double($0) }
            if parts.count == 2 {
                DispatchQueue.main.async { NSApp.windows.first?.setContentSize(NSSize(width: parts[0], height: parts[1])) }
            }
        }
        guard args.contains("--demo") else { return }
        var installed = store.installed
        let inlet = installed.removeValue(forKey: "inlet")
        let ferry = installed["ferry"]
        if let ferry { installed["ferry"] = Installed(url: ferry.url, version: "1.1", schema: ferry.schema) }
        store.freezeForDemo(installed: installed)

        Task {
            try? await Task.sleep(for: .seconds(3))
            await voyage("inlet", store: store)
            if let inlet { installed["inlet"] = inlet }
            store.freezeForDemo(installed: installed)
            try? await Task.sleep(for: .seconds(4))
            store.installer.setPreview(.idle, for: "inlet")

            try? await Task.sleep(for: .seconds(2))
            await voyage("ferry", store: store)
            if let ferry { installed["ferry"] = ferry }
            store.freezeForDemo(installed: installed)
            try? await Task.sleep(for: .seconds(2.5))
            store.installer.setPreview(.idle, for: "ferry")
        }
    }

    private static func voyage(_ id: String, store: HarborStore) async {
        let replacing = store.installed[id] != nil
        for step in 0...40 {
            store.installer.setPreview(.downloading(Double(step) / 40), for: id, replacing: replacing)
            try? await Task.sleep(for: .milliseconds(150))
        }
        store.installer.setPreview(.installing, for: id, replacing: replacing)
        try? await Task.sleep(for: .seconds(1.2))
        store.installer.setPreview(.done, for: id, replacing: replacing)
    }
}
#endif
