import HarborKit
import SwiftUI

@main
struct HarborApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = HarborStore()

    var body: some Scene {
        Window("Harbor", id: "main") {
            ContentView(store: store)
                .tint(Theme.ink)
                .frame(minWidth: 820, minHeight: 560)
                .onAppear {
                    store.start()
                    #if DEBUG
                    DemoDriver.runIfRequested(store)
                    #endif
                }
                .onOpenURL { store.handle($0) }
        }
        .defaultSize(width: 1000, height: 720)
        // The shore runs to the top of the window, under the traffic lights.
        .windowStyle(.hiddenTitleBar)

        Settings {
            HarborSettings()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        PreviewRenderer.runIfRequested()
        #endif
        // Opened hidden (macOS bringing apps back at login does this), the
        // window never shows and Harbor would sit in the Dock "running in
        // the background" with nothing to do there. It has no background
        // work, so it leaves instead; opening it again starts it fresh.
        DispatchQueue.main.async {
            if NSApp.isHidden { NSApp.terminate(nil) }
        }
        watchForNoWindow()
        #if DEBUG
        // `--order-out` puts every window away, to check the watch below.
        if CommandLine.arguments.contains("--order-out") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.windows.forEach { $0.orderOut(nil) } }
        }
        #endif
    }

    private var windowless = 0

    /// Whatever way Harbor ends up running with no window (the Dock then
    /// calls it "running in the background"), it leaves after a few seconds,
    /// since it has nothing to do there. Hidden on purpose with ⌘H, it stays.
    private func watchForNoWindow() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let showing = NSApp.windows.contains { window in
                    !(window is NSPanel) && (window.isVisible || window.isMiniaturized)
                }
                if showing || NSApp.isHidden {
                    self.windowless = 0
                } else {
                    self.windowless += 1
                    if self.windowless >= 2 { NSApp.terminate(nil) }
                }
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Harbor is only a window; closing it is quitting it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Harbor's own preferences: just the language.
private struct HarborSettings: View {
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current

    var body: some View {
        Form {
            Picker("Language", selection: $language) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            .onChange(of: language) { _, language in language.apply() }
            if language != launchLanguage {
                HStack {
                    Text("Restart Harbor to switch languages.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restart Now") { AppLanguage.relaunch() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
