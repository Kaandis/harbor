import HarborKit
import SwiftUI

/// The window is the harbour. With nothing open it fills most of the window
/// above the harbour master's desk; opening an app (or the office, for
/// Harbor itself) draws the harbour in to a strip along the quay and the
/// page rises from below, under the boat that was chosen.
struct ContentView: View {
    @Bindable var store: HarborStore
    @Namespace private var icons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let deskHeight: CGFloat = 150

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let open = store.selection != nil
            let layout = HarbourLayout(apps: store.shelf.count)
            let full = min(width / HarbourGeometry.width, (proxy.size.height - Self.deskHeight) / layout.height)
            let compact = min(width / HarbourGeometry.width, 0.74)
            let k = open ? compact : full
            // Open, the harbour shrinks to the quay; closed, the sea runs on
            // down to the desk however tall the window is.
            let mapHeight = open ? layout.collapsedHeight * k
                                 : max(layout.height * k, proxy.size.height - Self.deskHeight)

            VStack(spacing: 0) {
                HarbourMap(store: store, k: k, viewWidth: width, select: select)
                    .frame(width: width, height: mapHeight, alignment: .top)
                    .clipped()
                    .overlay(alignment: .top) { WindowDragStrip() }

                ZStack(alignment: .top) {
                    Theme.background
                    if let id = store.selection {
                        page(for: id)
                            .id(id)
                            .transition(pageTransition(for: id, width: width, k: k))
                    } else {
                        DeskView(store: store)
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .top) {
                    // Where the page meets the harbour, a soft edge instead of a line.
                    LinearGradient(colors: [.black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 6)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .onExitCommand { select(nil) }
    }

    @ViewBuilder
    private func page(for id: String) -> some View {
        if id == HarborStore.officeID {
            OfficeView(store: store, back: { select(nil) })
        } else if let app = store.shelf.first(where: { $0.id == id }) {
            AppDetailView(store: store, app: app, icons: icons, back: { select(nil) })
        }
    }

    /// The page grows out of the spot under its boat, and returns there.
    private func pageTransition(for id: String, width: CGFloat, k: CGFloat) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let x: CGFloat
        if let index = store.shelf.firstIndex(where: { $0.id == id }) {
            x = HarbourFrame(k: k, viewWidth: width).x(HarbourLayout(apps: store.shelf.count).berths[index].x)
        } else {
            x = HarbourFrame(k: k, viewWidth: width).x(HarbourGeometry.office.midX)
        }
        let anchor = UnitPoint(x: width > 0 ? x / width : 0.5, y: 0)
        return .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }

    private func select(_ id: String?) {
        guard id != store.selection else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 1)) {
            store.selection = id
        }
    }
}

/// The title bar is hidden so the shore runs to the top of the window; this
/// strip keeps the window draggable there.
private struct WindowDragStrip: View {
    var body: some View {
        Color.clear
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
    }
}

/// Under the harbour when nothing is open: what's in port, and the buttons
/// that look for and fetch updates.
private struct DeskView: View {
    var store: HarborStore

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Harbor")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                Text(summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink2)
                    .transaction { $0.animation = nil }
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        Task { await store.checkForUpdates() }
                    } label: {
                        Label(store.isChecking ? "Checking…" : "Check for Updates", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(HarborButtonStyle(prominent: store.updateCount == 0))
                    .disabled(store.isChecking)
                    if store.updateCount > 0 {
                        Button {
                            Task { await store.updateAll() }
                        } label: {
                            Text(store.updateCount == 1 ? "Update" : "Update All (\(store.updateCount))")
                        }
                        .buttonStyle(HarborButtonStyle())
                    }
                }
                if let date = store.lastChecked {
                    Text("Checked \(date, format: .relative(presentation: .named))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
        .padding(.horizontal, 40)
        .frame(maxHeight: .infinity)
    }

    private var summary: String {
        let moored = store.shelf.filter { store.installed[$0.id] != nil }.count
        let waiting = store.shelf.count - moored
        var parts = [String(localized: "\(moored) of \(store.shelf.count) apps in port")]
        if store.updateCount > 0 { parts.append(String(localized: "\(store.updateCount) with an update")) }
        if waiting > 0 { parts.append(String(localized: "\(waiting) at anchor, ready to install")) }
        return parts.joined(separator: " · ")
    }
}

/// Harbor's own page: its version and updates, and the apps' shared home.
private struct OfficeView: View {
    var store: HarborStore
    let back: () -> Void

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        LiveScroll {
            VStack(alignment: .leading, spacing: 22) {
                Button(action: back) {
                    Label("All Apps", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(PressableStyle())
                .keyboardShortcut("[", modifiers: .command)

                HStack(alignment: .center, spacing: 20) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Harbor")
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-0.9)
                            .foregroundStyle(Theme.ink)
                        Text("The harbour master’s office: where the Harbor apps are kept up to date.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink2)
                        Text("Version \(version)")
                            .font(.system(size: 12.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.ink3)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 12)
                    if let harbor = store.harborUpdate {
                        InstallButton(store: store, app: harbor)
                    }
                }

                Card(title: "Updates") {
                    Text("Harbor reads a small public catalog at most twice a day, or when you check, and downloads an app only when you install or update it. Every download is checked against the catalog’s SHA-256 before it’s put in place.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Button {
                            Task { await store.checkForUpdates() }
                        } label: {
                            Label(store.isChecking ? "Checking…" : "Check for Updates", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(HarborButtonStyle(prominent: false))
                        .disabled(store.isChecking)
                        if let date = store.lastChecked {
                            Text("Checked \(date, format: .relative(presentation: .named))")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.ink3)
                        }
                    }
                    .padding(.top, 4)
                }

                Card(title: "About") {
                    Text("Free Mac apps that share one look and one place for their settings.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink)
                    Link(destination: URL(string: "https://kaandis.github.io/harbor/")!) {
                        Label("Website", systemImage: "safari")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// A vertical ScrollView, except while `ImageRenderer` draws previews, which
/// leaves scroll views blank.
struct LiveScroll<Content: View>: View {
    @Environment(\.isStaticRender) private var isStaticRender
    @ViewBuilder let content: Content

    var body: some View {
        if isStaticRender { content } else { ScrollView { content } }
    }
}
