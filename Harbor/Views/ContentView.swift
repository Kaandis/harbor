import HarborKit
import SwiftUI

/// The sidebar lists the apps; the main area is either the shelf of all apps
/// or one app's page, which grows out of its tile on the shelf.
struct ContentView: View {
    @Bindable var store: HarborStore
    @Namespace private var icons
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            Sidebar(store: store, select: select)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let id = store.selection, let app = store.shelf.first(where: { $0.id == id }) {
                    AppDetailView(store: store, app: app, icons: icons, back: { select(nil) })
                        .id(app.id)
                        .transition(.opacity)
                } else {
                    ShelfView(store: store, icons: icons, open: { select($0.id) })
                        .transition(.opacity)
                }
            }
        }
    }

    private func select(_ id: String?) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .harborPresent) { store.selection = id }
    }
}

private struct Sidebar: View {
    var store: HarborStore
    let select: (String?) -> Void

    var body: some View {
        List(selection: Binding(get: { store.selection ?? "all" }, set: { select($0 == "all" ? nil : $0) })) {
            Label("All Apps", systemImage: "square.grid.2x2")
                .tag("all")
            Section("Apps") {
                ForEach(store.shelf) { app in
                    HStack(spacing: 8) {
                        Image(nsImage: store.icon(for: app))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(app.name)
                        Spacer()
                        if store.status(of: app).isUpdate {
                            Circle().fill(Accent.pebble.color).frame(width: 7, height: 7)
                                .accessibilityLabel(Text("Update available"))
                        }
                    }
                    .tag(app.id)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { UpdateFooter(store: store) }
    }
}

private struct UpdateFooter: View {
    var store: HarborStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let harbor = store.harborUpdate {
                HarborUpdateRow(store: store, harbor: harbor)
                    .padding(.bottom, 8)
            }
            if store.updateCount > 1 {
                Button {
                    Task { await store.updateAll() }
                } label: {
                    Label("Update All (\(store.updateCount))", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
            }
            Button {
                Task { await store.checkForUpdates() }
            } label: {
                Label(store.isChecking ? "Checking…" : "Check for Updates", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isChecking)
            if let date = store.lastChecked {
                Text("Checked \(date, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

/// "Harbor 0.3 is available", with a button that updates Harbor itself.
private struct HarborUpdateRow: View {
    var store: HarborStore
    let harbor: CatalogApp

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Harbor \(harbor.latestVersion) is available")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.ink)
            InstallButton(store: store, app: harbor, compact: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
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
