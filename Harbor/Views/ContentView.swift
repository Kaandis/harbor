import HarborKit
import SwiftUI

/// The window is the harbour. With nothing open it fills most of the window
/// above the harbour master's desk; opening an app (or the office, for
/// Harbor itself) draws the harbour in to a strip along the quay and the
/// page rises from below, under the boat that was chosen.
///
/// The page runs under the strip: scroll it and the harbour slides away with
/// it, so its settings get the whole window, with a slim bar to get back.
/// Scroll back to the top and keep pulling down, and letting go past the
/// mark takes you back to the harbour.
struct ContentView: View {
    @Bindable var store: HarborStore
    @Namespace private var icons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How far the open page has scrolled.
    @State private var scrolled: CGFloat = 0
    @State private var pullBack = PullBack()
    /// How far the page is pulled past its top, as the fingers say.
    @State private var pulled: CGFloat = 0

    private static let deskHeight: CGFloat = 150
    static let barHeight: CGFloat = 46

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
            // The harbour leaves with the page as it scrolls, 1:1.
            let lift = open ? min(max(scrolled, 0), mapHeight) : 0
            // The bar fades in over the last stretch before the harbour is gone.
            let barProgress = open ? min(max((lift - (mapHeight - Self.barHeight * 1.5)) / (Self.barHeight * 1.5), 0), 1) : 0
            // Pulled down past the top: how close to going back, 0 to 1.
            let pull = open ? min(pulled / PullBack.distance, 1) : 0

            ZStack(alignment: .top) {
                Theme.background

                if let id = store.selection {
                    page(for: id, inset: mapHeight)
                        .id(id)
                        .transition(pageTransition(for: id, width: width, k: k))
                } else {
                    DeskView(store: store)
                        .frame(height: max(proxy.size.height - mapHeight, 0))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.opacity)
                }

                HarbourMap(store: store, k: k, viewWidth: width, select: select)
                    .frame(width: width, height: mapHeight, alignment: .top)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        // Where the page meets the harbour, a soft edge instead of a line.
                        LinearGradient(colors: [.black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 6)
                            .offset(y: 6)
                            .allowsHitTesting(false)
                    }
                    .offset(y: -lift)

                if pull > 0 {
                    PullHint(progress: pull)
                        .offset(y: mapHeight + 10)
                        .allowsHitTesting(false)
                }

                WindowDragStrip()

                if open {
                    PageBar(title: title(for: store.selection), back: { select(nil) })
                        .opacity(barProgress)
                        .offset(y: (1 - barProgress) * -8)
                        .allowsHitTesting(barProgress > 0.5)
                }
            }
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .onExitCommand { select(nil) }
        .onAppear {
            pullBack.atTop = { store.selection != nil && scrolled <= 1 }
            pullBack.onPull = { pulled = $0 }
            pullBack.onBack = { select(nil) }
            pullBack.start()
        }
        .onDisappear { pullBack.stop() }
        .onChange(of: pulled >= PullBack.distance) { _, reached in
            // A tap on the trackpad as the mark is reached, like the system's own.
            if reached { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
        }
    }

    @ViewBuilder
    private func page(for id: String, inset: CGFloat) -> some View {
        let onScroll: (CGFloat) -> Void = { scrolled = $0 }
        if id == HarborStore.officeID {
            OfficeView(store: store, inset: inset, onScroll: onScroll, back: { select(nil) })
        } else if let app = store.shelf.first(where: { $0.id == id }) {
            AppDetailView(store: store, app: app, icons: icons, inset: inset, onScroll: onScroll, back: { select(nil) })
        }
    }

    private func title(for id: String?) -> String {
        if id == HarborStore.officeID { return "Harbor" }
        return store.shelf.first { $0.id == id }?.name ?? ""
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
        let anchor = UnitPoint(x: width > 0 ? x / width : 0.5, y: 0.3)
        return .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }

    private func select(_ id: String?) {
        guard id != store.selection else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 1)) {
            store.selection = id
            scrolled = 0
        }
    }
}

/// The slim bar that takes over once the harbour has scrolled away: the way
/// back, and where you are.
private struct PageBar: View {
    let title: String
    let back: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .bottom) { Divider().overlay(Theme.hairline) }
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .allowsHitTesting(false)
            HStack {
                Button(action: back) {
                    Label("All Apps", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(PressableStyle())
                Spacer()
            }
            // Clear of the traffic lights.
            .padding(.leading, 84)
        }
        .frame(height: ContentView.barHeight)
    }
}

/// Shows how far a pull past the top has come: an arrow toward the harbour
/// that fills in, and says so once letting go will take you back.
private struct PullHint: View {
    let progress: CGFloat

    var body: some View {
        let ready = progress >= 1
        HStack(spacing: 7) {
            Image(systemName: ready ? "arrow.up.circle.fill" : "arrow.up.circle")
                .font(.system(size: 16, weight: .medium))
                .rotationEffect(.degrees(Double(1 - progress) * 180))
            Text(ready ? "Release for the harbour" : "Pull for the harbour")
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundStyle(ready ? Theme.ink : Theme.ink2)
        .opacity(Double(min(progress * 1.6, 1)))
        .animation(.harborSelect, value: ready)
    }
}

/// Going back by pulling past the top of a page. It reads the fingers
/// themselves (trackpad or Magic Mouse) rather than the scroll view's bounce:
/// once the page is at its top, every bit of pull down adds up, any push up
/// takes it back, and letting go far enough goes back to the harbour.
@MainActor
final class PullBack {
    /// How far past the top counts, in the damped points the page moves.
    static let distance: CGFloat = 64
    var atTop: () -> Bool = { false }
    var onPull: (CGFloat) -> Void = { _ in }
    var onBack: () -> Void = {}
    private var monitor: Any?
    private var pulled: CGFloat = 0

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            // Local monitors run on the main thread.
            let phase = event.phase, delta = event.scrollingDeltaY
            MainActor.assumeIsolated { self?.handle(phase: phase, delta: delta) }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(phase: NSEvent.Phase, delta: CGFloat) {
        switch phase {
        case .began:
            set(0)
        case .changed:
            // Positive is the page moving down: a pull past the top. Halved,
            // as the page's own bounce gives way.
            guard atTop() || pulled > 0 else { return }
            set(max(pulled + delta * 0.5, 0))
        case .ended, .cancelled:
            let back = phase == .ended && pulled >= Self.distance
            set(0)
            if back { onBack() }
        default:
            break
        }
    }

    private func set(_ value: CGFloat) {
        guard value != pulled else { return }
        pulled = value
        onPull(value)
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
    let inset: CGFloat
    let onScroll: (CGFloat) -> Void
    let back: () -> Void

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        LiveScroll(inset: inset, onScroll: onScroll) {
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
/// leaves scroll views blank. Its content starts `inset` down, under the
/// harbour, and it reports how far it has scrolled.
struct LiveScroll<Content: View>: View {
    var inset: CGFloat = 0
    var onScroll: (CGFloat) -> Void = { _ in }
    @Environment(\.isStaticRender) private var isStaticRender
    @ViewBuilder let content: Content

    var body: some View {
        if isStaticRender {
            content.padding(.top, inset)
        } else {
            ScrollView {
                content.padding(.top, inset)
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                onScroll(offset)
            }
        }
    }
}
