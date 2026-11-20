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
