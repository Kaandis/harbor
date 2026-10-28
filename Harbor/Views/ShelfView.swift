import HarborKit
import SwiftUI

/// Every Harbor app as a tile, moored side by side.
struct ShelfView: View {
    var store: HarborStore
    let icons: Namespace.ID
    let open: (CatalogApp) -> Void

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 18)]

    var body: some View {
        LiveScroll {
            VStack(alignment: .leading, spacing: 0) {
                Text("Harbor")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1.4)
                    .foregroundStyle(Theme.ink)
                Text("Free Mac apps that share one look and one place for their settings.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 4)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(store.apps) { app in
                        AppTile(app: app, icon: store.icon(for: app), status: store.status(of: app), icons: icons) {
                            open(app)
                        }
                    }
                }
                .padding(.top, 30)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AppTile: View {
    let app: CatalogApp
    let icon: NSImage
    let status: AppStatus
    let icons: Namespace.ID
    let action: () -> Void
    @State private var hovering = false
    private let language = AppLanguage.resolvedLocale.identifier

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .matchedGeometryEffect(id: "icon-\(app.id)", in: icons)
                    .padding(.leading, -8)
                Text(app.name)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 10)
                Text(app.tagline.localized(language))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(2, reservesSpace: true)
                    .padding(.top, 2)
                StatusChip(status: status)
                    .padding(.top, 14)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(hovering ? 0.08 : 0.03), radius: hovering ? 14 : 6, y: hovering ? 6 : 2)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in withAnimation(.harborSelect) { hovering = inside } }
        .accessibilityLabel(Text("\(app.name), \(app.tagline.localized(language))"))
    }
}

/// Installed, an update waiting, or not here yet.
struct StatusChip: View {
    let status: AppStatus

    var body: some View {
        Group {
            switch status {
            case .current(let version):
                Label { Text("Installed · \(version)") } icon: { Image(systemName: "checkmark") }
                    .foregroundStyle(Theme.ink2)
                    .background(Capsule().fill(Theme.raised).padding(-1))
            case .updateAvailable(_, let latest):
                Label { Text("Update · \(latest)") } icon: { Image(systemName: "arrow.down") }
                    .foregroundStyle(Theme.background)
                    .background(Capsule().fill(Theme.ink).padding(-1))
            case .notInstalled:
                Label { Text("Not installed") } icon: { Image(systemName: "plus") }
                    .foregroundStyle(Theme.ink2)
                    .background(Capsule().strokeBorder(Theme.hairline, lineWidth: 1.5).padding(-1))
            }
        }
        .font(.system(size: 11.5, weight: .semibold))
        .labelStyle(ChipLabelStyle())
    }
}

private struct ChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 9, weight: .bold))
            configuration.title
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
    }
}
