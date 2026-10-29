import HarborKit
import SwiftUI

/// The harbour seen from above. Every Harbor app is a boat: moored at its
/// berth when it's installed, waiting at anchor beyond the breakwater when
/// it isn't. Installing one sails it in through the mouth as the download
/// arrives, and an update comes alongside on a supply boat. Nothing moves
/// unless something is happening.
struct HarbourMap: View, Animatable {
    var store: HarborStore
    /// Design space → view scale. Animatable, so the harbour glides between
    /// its full and its compact size.
    var k: CGFloat
    let viewWidth: CGFloat
    let select: (String?) -> Void

    var animatableData: CGFloat {
        get { k }
        set { k = newValue }
    }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered: String?
    @State private var ripples: [Ripple] = []
    private let language = AppLanguage.resolvedLocale.identifier

    var body: some View {
        let frame = HarbourFrame(k: k, viewWidth: viewWidth)
        let palette = HarbourPalette.for(scheme)
        let layout = HarbourLayout(apps: store.shelf.count)
        let boats = boatStates(layout)
        let reserved = layout.berths[layout.berths.count - 1]

        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                HarbourScenery.draw(in: &context, size: size, frame: frame, layout: layout,
                                    berths: boats.map(\.mark) + [BerthMark(berth: reserved, moored: false, anchoredAt: nil)],
                                    palette: palette)
            }
            .gesture(SpatialTapGesture().onEnded { ripple(at: frame.scenePoint($0.location)) })
            .accessibilityHidden(true)

            ForEach(ripples) { RippleView(ripple: $0, frame: frame) }

            OfficeBuilding(store: store, frame: frame, palette: palette, selected: store.selection == HarborStore.officeID) {
                select(HarborStore.officeID)
            }

            ForEach(boats) { boat in
                BerthLabel(title: boat.app.name, detail: boat.versionText, berth: boat.berth, layout: layout, frame: frame,
                           selected: store.selection == boat.app.id) { select(boat.app.id) }
            }
            BerthLabel(title: String(localized: "Next ship"), detail: String(localized: "On its way"),
                       berth: reserved, layout: layout, frame: frame, selected: false, action: nil)
            ForEach(boats) { boat in boatLayers(boat, layout: layout, frame: frame, palette: palette) }
        }
        .frame(width: viewWidth, alignment: .topLeading)
        .clipped()
    }

    // MARK: Boats

    @ViewBuilder
    private func boatLayers(_ boat: BoatState, layout: HarbourLayout, frame: HarbourFrame, palette: HarbourPalette) -> some View {
        let G = HarbourGeometry.self
        let lifted = hovered == boat.app.id && !reduceMotion
        let selected = store.selection == boat.app.id
        let voyage = VoyageEffect.self

        Button { select(boat.app.id) } label: {
            BoatHullView(palette: palette, selected: selected, tender: false)
                .frame(width: G.boatLength * frame.k, height: G.boatWidth * frame.k)
                .scaleEffect(lifted ? 1.035 : 1)
        }
        .buttonStyle(BoatPressStyle())
        .onHover { inside in
            withAnimation(.harborSelect) { hovered = inside ? boat.app.id : (hovered == boat.app.id ? nil : hovered) }
            if inside { ripple(at: boat.arrival.position(at: boat.t), quiet: true) }
        }
        .accessibilityLabel(Text("\(boat.app.name), \(boat.statusText)"))
        .modifier(voyage.init(t: boat.t, voyage: boat.arrival, frame: frame, placement: .hull))
        .animation(voyageAnimation, value: boat.t)

        Image(nsImage: store.icon(for: boat.app))
            .resizable()
            .frame(width: HarbourGeometry.iconSize * frame.k, height: HarbourGeometry.iconSize * frame.k)
            .scaleEffect(lifted ? 1.05 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .modifier(voyage.init(t: boat.t, voyage: boat.arrival, frame: frame, placement: .center))
            .animation(voyageAnimation, value: boat.t)

        if let caption = boat.caption {
            BoatCaption(caption: caption, k: frame.k) { store.primaryAction(for: boat.app) }
                .modifier(voyage.init(t: boat.t, voyage: boat.arrival, frame: frame,
                                      placement: .caption(gap: 8, length: G.boatLength, width: G.boatWidth,
                                                          above: boat.berth.row == 1 && boat.isMoored)))
                .animation(voyageAnimation, value: boat.t)
                .transition(.opacity)
        }

        if let supply = boat.supply {
            BoatHullView(palette: palette, selected: false, tender: true)
                .frame(width: G.tenderLength * frame.k, height: G.tenderWidth * frame.k)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .modifier(voyage.init(t: supply.t, voyage: layout.supply(to: boat.berth), frame: frame, placement: .tender))
                .animation(voyageAnimation, value: supply.t)
                .transition(.opacity)
            BoatCaption(caption: supply.caption, k: frame.k, action: nil)
                .modifier(voyage.init(t: supply.t, voyage: layout.supply(to: boat.berth), frame: frame,
                                      placement: .caption(gap: 6, length: G.tenderLength, width: G.tenderWidth,
                                                          above: boat.berth.row == 1)))
                .animation(voyageAnimation, value: supply.t)
                .transition(.opacity)
        }
    }

    private var voyageAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 1)
    }

    private func boatStates(_ layout: HarbourLayout) -> [BoatState] {
        // Apps at anchor line up in order, without gaps for those in port.
        var waiting = 0
        return store.shelf.enumerated().map { index, app in
            let anchor = waiting
            if store.installed[app.id] == nil { waiting += 1 }
            return BoatState(app: app, index: anchor, berth: layout.berths[index], layout: layout, status: store.status(of: app),
                      phase: store.installer.phase(of: app), replacing: store.installer.replacing.contains(app.id),
                      removing: store.uninstaller.phase(of: app) == .working, language: language)
        }
    }

    // MARK: Ripples

    private func ripple(at scenePoint: CGPoint, quiet: Bool = false) {
        guard !reduceMotion else { return }
        let ripple = Ripple(center: scenePoint, quiet: quiet)
        ripples.append(ripple)
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            ripples.removeAll { $0.id == ripple.id }
        }
    }
}

// MARK: - State

/// Where one app's boat is and what it says.
struct BoatState: Identifiable {
    let app: CatalogApp
    let berth: Berth
    let arrival: Voyage
    /// How far along its arrival the boat is: 0 at anchor, 1 moored.
    let t: CGFloat
    let caption: BoatCaption.Caption?
    let supply: (t: CGFloat, caption: BoatCaption.Caption)?
    let statusText: String
    let versionText: String

    var id: String { app.id }
    var isMoored: Bool { t >= 1 }

    var mark: BerthMark {
        BerthMark(berth: berth, moored: isMoored, anchoredAt: t == 0 ? arrival.points.first : nil)
    }

    init(app: CatalogApp, index: Int, berth: Berth, layout: HarbourLayout, status: AppStatus, phase: Installer.Phase,
         replacing: Bool, removing: Bool, language: String) {
        self.app = app
        self.berth = berth
        arrival = layout.arrival(from: index, to: berth)

        let installed: Bool
        switch status {
        case .notInstalled:
            installed = false
            statusText = String(localized: "Not installed")
            versionText = String(localized: "At anchor")
        case .current(let version):
            installed = true
            statusText = String(localized: "Installed · \(version)")
            versionText = version
        case .updateAvailable(let version, let latest):
            installed = true
            statusText = String(localized: "Update · \(latest)")
            versionText = "\(version) → \(latest)"
        }

        // Progress along a voyage: the download carries the boat most of the
        // way, unpacking brings it alongside.
        func along(_ phase: Installer.Phase) -> CGFloat? {
            switch phase {
            case .downloading(let f): 0.05 + 0.82 * f
            case .installing: 0.94
            case .done: 1
            case .idle, .failed: nil
            }
        }
        func progressCaption(_ phase: Installer.Phase) -> BoatCaption.Caption? {
            switch phase {
            case .downloading(let f): .progress("\(Int(f * 100))%")
            case .installing: .progress(String(localized: "Installing…"))
            case .done: .done(String(localized: "Installed"))
            case .idle, .failed: nil
            }
        }

        if installed {
            t = 1
            if removing {
                supply = nil
                caption = .progress(String(localized: "Casting off…"))
            } else if case .done = phase {
                // Arrived: a fresh install just moored, an update was just delivered.
                supply = nil
                caption = .done(replacing ? String(localized: "Updated") : String(localized: "Installed"))
            } else if let s = along(phase), let caption = progressCaption(phase) {
                supply = (s, caption)
                self.caption = nil
            } else {
                supply = nil
                if case .updateAvailable = status {
                    // Short, so neighbouring berths' tags never touch; the quay
                    // already shows which version is coming.
                    caption = .action(app.canInstall ? String(localized: "Update") : String(localized: "Update ↗"))
                } else if case .failed = phase {
                    caption = .action(String(localized: "Try Again"))
                } else {
                    caption = nil
                }
            }
        } else {
            supply = nil
            t = along(phase) ?? 0
            switch phase {
            case .downloading, .installing, .done: caption = progressCaption(phase)
            case .failed: caption = .action(String(localized: "Try Again"))
            case .idle: caption = .action(app.canInstall ? String(localized: "Install") : String(localized: "Get on the Website ↗"))
            }
        }
    }
}

// MARK: - Placement

/// Puts a layer at a point along a voyage. The hull turns with the boat;
/// the icon and captions stay upright so they're always readable.
struct VoyageEffect: GeometryEffect {
    enum Placement: Equatable {
        case hull, tender, center
        /// Upright, clear of a hull of this size: below it, or above it for
        /// a boat moored facing the quay.
        case caption(gap: CGFloat, length: CGFloat, width: CGFloat, above: Bool)
    }

    var t: CGFloat
    let voyage: Voyage
    let frame: HarbourFrame
    let placement: Placement

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let G = HarbourGeometry.self
        let c = frame.point(voyage.position(at: t))
        let heading = voyage.heading(at: t)
        var transform = CGAffineTransform(translationX: c.x, y: c.y)
        switch placement {
        case .hull, .tender:
            transform = transform.rotated(by: heading)
        case .center:
            break
        case .caption(let gap, let length, let width, let above):
            let extent = abs(sin(heading)) * length / 2 + abs(cos(heading)) * width / 2
            let distance = (extent + gap) * frame.k + size.height / 2
            transform = transform.translatedBy(x: 0, y: above ? -distance : distance)
        }
        return ProjectionTransform(transform.translatedBy(x: -size.width / 2, y: -size.height / 2))
    }
}

// MARK: - Pieces

struct BoatHullView: View {
    let palette: HarbourPalette
    let selected: Bool
    let tender: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                BoatHull()
                    .fill(tender ? palette.tender : palette.hull)
                    .shadow(color: palette.shadow, radius: size.height * 0.1, x: 0, y: size.height * 0.1)
                BoatHull().stroke(palette.hullEdge, lineWidth: 1)
                if tender {
                    // Cargo on deck.
                    HStack(spacing: size.height * 0.1) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(palette.wood)
                                .frame(width: size.height * 0.42, height: size.height * 0.42)
                        }
                    }
                    .offset(x: -size.width * 0.06)
                } else {
                    BoatHull()
                        .fill(palette.deck)
                        .frame(width: size.width * 0.6, height: size.height * 0.62)
                        .offset(x: -size.width * 0.07)
                }
                if selected {
                    BoatHull()
                        .stroke(Theme.ink, lineWidth: 2.5)
                        .padding(-5)
                }
            }
        }
    }
}

/// Pressing a boat dips it a little, right away.
private struct BoatPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.harborPress, value: configuration.isPressed)
    }
}

/// A small upright tag under a boat: Install or Update, or progress.
struct BoatCaption: View {
    enum Caption: Equatable {
        case action(String)
        case progress(String)
        case done(String)
    }

    let caption: Caption
    let k: CGFloat
    let action: (() -> Void)?

    var body: some View {
        let size = max(10.5, 12.5 * k)
        switch caption {
        case .action(let title):
            Button { action?() } label: {
                Text(title)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 10 * max(k, 0.8))
                    .frame(height: max(20, 24 * k))
                    .background(Capsule().fill(Theme.ink))
                    .fixedSize()
            }
            .buttonStyle(PressableStyle())
        case .progress(let title):
            Text(title)
                .font(.system(size: size, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 9 * max(k, 0.8))
                .frame(height: max(18, 22 * k))
                .background(Capsule().fill(Theme.card))
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .fixedSize()
                .transaction { $0.animation = nil }
        case .done(let title):
            Label(title, systemImage: "checkmark")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 9 * max(k, 0.8))
                .frame(height: max(18, 22 * k))
                .background(Capsule().fill(Theme.card))
                .fixedSize()
        }
    }
}

/// An app's name painted on the quay above its berth, or for the row along
/// the breakwater, on a small plaque outside the wall.
private struct BerthLabel: View {
    let title: String
    let detail: String
    let berth: Berth
    let layout: HarbourLayout
    let frame: HarbourFrame
    let selected: Bool
    let action: (() -> Void)?

    var body: some View {
        let onWall = berth.row == 1
        let label = VStack(spacing: 1) {
            Text(title)
                .font(.system(size: max(11, 14 * frame.k), weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(selected ? Theme.ink : action == nil ? Theme.ink3 : Theme.ink2)
            Text(detail)
                .font(.system(size: max(9.5, 11 * frame.k), weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.ink3)
        }
        .fixedSize()
        .padding(.horizontal, onWall ? 8 : 0)
        .padding(.vertical, onWall ? 3 : 0)
        .background {
            if onWall { RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.card.opacity(0.92)) }
        }
        .transaction { $0.animation = nil }

        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(PressableStyle())
            } else {
                label
            }
        }
        .accessibilityHidden(true)
        .position(frame.point(CGPoint(x: berth.x, y: onWall ? layout.wallY + 30 : 44)))
    }
}

/// The harbour master's office stands for Harbor itself. A flag flies when
/// a newer Harbor is out.
private struct OfficeBuilding: View {
    var store: HarborStore
    let frame: HarbourFrame
    let palette: HarbourPalette
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let k = frame.k
        let rect = HarbourGeometry.office
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        Button(action: action) {
            HStack(alignment: .center, spacing: 10 * k) {
                ZStack(alignment: .topLeading) {
                    // The building from above: a gabled roof, its sunlit slope
                    // lighter than the shaded one, casting a soft shadow.
                    VStack(spacing: 0) {
                        Rectangle().fill(palette.roofRidge)
                        Rectangle().fill(palette.roof)
                    }
                    .overlay(alignment: .center) { Rectangle().fill(palette.roof.opacity(0.6)).frame(height: 1.5 * k) }
                    .clipShape(RoundedRectangle(cornerRadius: 2.5 * k))
                        .frame(width: 54 * k, height: 34 * k)
                        .shadow(color: palette.shadow.opacity(0.7), radius: 2 * k, x: 3 * k, y: 4 * k)
                        .overlay {
                            if store.isChecking { SignalRings(k: k) }
                        }
                        .offset(y: 8 * k)
                    // A yellow flag goes up when a newer Harbor is out.
                    if store.harborUpdate != nil {
                        Circle().fill(Theme.ink)
                            .frame(width: 5 * k, height: 5 * k)
                            .offset(x: 60 * k, y: 6 * k)
                        Pennant()
                            .fill(palette.tender)
                            .overlay(Pennant().stroke(Theme.ink.opacity(0.6), lineWidth: 0.8))
                            .frame(width: 16 * k, height: 8 * k)
                            .offset(x: 63 * k, y: 4.5 * k)
                    }
                }
                .frame(width: 80 * k, height: rect.height * k, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Harbor")
                        .font(.system(size: max(11, 14 * k), weight: .semibold))
                        .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                    Text(store.harborUpdate.map { String(localized: "\($0.latestVersion) is out") } ?? version)
                        .font(.system(size: max(9.5, 11 * k), weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.ink3)
                }
                .fixedSize()
            }
            .scaleEffect(hovering ? 1.03 : 1)
            .transaction { $0.animation = nil }
        }
        .buttonStyle(PressableStyle())
        .onHover { inside in withAnimation(.harborSelect) { hovering = inside } }
        .accessibilityLabel(Text("Harbor"))
        .offset(x: frame.x(rect.minX), y: frame.y(rect.minY))
    }
}

/// While Harbor checks for updates, rings go out from the office roof like
/// a radio call to sea. They run only while the check does.
private struct SignalRings: View {
    let k: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var going = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Theme.ink.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 70 * k, height: 70 * k)
                    .scaleEffect(going ? 1 : 0.1)
                    .opacity(going ? 0 : 0.9)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.5), value: going)
            }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .onAppear { going = true }
    }
}

private struct Pennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct Ripple: Identifiable {
    let id = UUID()
    let center: CGPoint
    let quiet: Bool
}

/// A ring spreading on the water where it was touched.
private struct RippleView: View {
    let ripple: Ripple
    let frame: HarbourFrame
    @State private var spread = false

    var body: some View {
        let size = (ripple.quiet ? 120 : 90) * frame.k
        Circle()
            .stroke(Color.white.opacity(ripple.quiet ? 0.35 : 0.7), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(spread ? 1 : 0.15)
            .opacity(spread ? 0 : 1)
            .position(frame.point(ripple.center))
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { spread = true } }
    }
}
