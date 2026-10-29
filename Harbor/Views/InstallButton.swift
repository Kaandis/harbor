import HarborKit
import SwiftUI

/// Open, Install or Update — and while it works, the button itself fills up
/// with the download and then says what it's doing.
struct InstallButton: View {
    var store: HarborStore
    let app: CatalogApp
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let phase = store.installer.phase(of: app)
        VStack(alignment: compact ? .leading : .trailing, spacing: 6) {
            switch phase {
            case .downloading(let fraction):
                ProgressPill(fraction: fraction, label: "Downloading \(Int(fraction * 100))%", compact: compact)
                    .animation(reduceMotion ? nil : .harborSelect, value: fraction)
            case .installing:
                ProgressPill(fraction: 1, label: "Installing…", compact: compact)
            case .done:
                Label("Updated", systemImage: "checkmark")
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(height: compact ? 26 : 30)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        store.installer.reset(app)
                    }
            case .idle, .failed:
                Button { store.primaryAction(for: app) } label: { Text(title) }
                    .buttonStyle(HarborButtonStyle())
                    .controlSize(compact ? .small : .regular)
                if case .failed(let message) = phase {
                    Text(message)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(compact ? .leading : .trailing)
                        .frame(maxWidth: 260, alignment: compact ? .leading : .trailing)
                    Link("Open the Website", destination: app.site)
                        .font(.system(size: 11.5, weight: .medium))
                }
            }
        }
        .animation(reduceMotion ? nil : .harborPresent, value: phase)
    }

    private var title: LocalizedStringKey {
        if app.isHub { return "Update and Restart" }
        switch store.status(of: app) {
        case .notInstalled: return app.canInstall ? "Install" : "Get on the Website ↗"
        case .updateAvailable(_, let latest): return app.canInstall ? "Update to \(latest)" : "Update to \(latest) ↗"
        case .current: return "Open"
        }
    }
}

/// A capsule that fills from the left as work completes.
private struct ProgressPill: View {
    let fraction: Double
    let label: LocalizedStringKey
    let compact: Bool

    var body: some View {
        Text(label)
            .font(.system(size: compact ? 12 : 13, weight: .semibold).monospacedDigit())
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: compact ? 26 : 30)
            .frame(minWidth: compact ? 150 : 170)
            .background(
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.raised)
                        Capsule().fill(Accent.pebble.color.opacity(0.45))
                            .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                    }
                }
            )
            .clipShape(Capsule())
            .accessibilityValue(Text("\(Int(fraction * 100)) percent"))
    }
}
