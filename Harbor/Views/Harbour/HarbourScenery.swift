import HarborKit
import SwiftUI

/// The harbour's colours: a bright day by default, and at night the water
/// darkens and lamps come on along the quay.
struct HarbourPalette {
    let shoreTop, shoreBottom, quayEdge, paving: Color
    let basinTop, basinBottom, sea, seaDeep, contour: Color
    let stone, stoneEdge, wood, rope: Color
    let hull, deck, hullEdge, tender: Color
    let tree, treeShade, roof, roofRidge: Color
    let shadow, ghost: Color
    let lamp: Color?

    static func `for`(_ scheme: ColorScheme) -> HarbourPalette {
        scheme == .dark ? night : day
    }

    static let day = HarbourPalette(
        shoreTop: hex(0xfbf0e2), shoreBottom: hex(0xf2e2cd), quayEdge: hex(0x231f1c), paving: hex(0x231f1c, 0.04),
        basinTop: hex(0x8fd0d8), basinBottom: hex(0x6cbcc8), sea: hex(0x4f9fbb), seaDeep: hex(0x3a86a6),
        contour: .white.opacity(0.22),
        stone: hex(0xf3e6d4), stoneEdge: hex(0x231f1c), wood: hex(0xc9a079), rope: hex(0x8a6a4c),
        hull: hex(0xfffbf6), deck: hex(0xe9d6b8), hullEdge: hex(0x231f1c, 0.16), tender: hex(0xf2c25a),
        tree: hex(0xa9bd93), treeShade: hex(0x8aa274), roof: hex(0x4d5560), roofRidge: hex(0x75808b),
        shadow: hex(0x0b3a44, 0.3), ghost: .white.opacity(0.6),
        lamp: nil)

    static let night = HarbourPalette(
        shoreTop: hex(0x2a2420), shoreBottom: hex(0x221d1a), quayEdge: hex(0x0f0d0c), paving: hex(0xffffff, 0.035),
        basinTop: hex(0x245866), basinBottom: hex(0x1d4b57), sea: hex(0x16384a), seaDeep: hex(0x102a38),
        contour: .white.opacity(0.09),
        stone: hex(0x4a4039), stoneEdge: hex(0x0f0d0c), wood: hex(0x7d6046), rope: hex(0xb8956c),
        hull: hex(0xece2d6), deck: hex(0xbca383), hullEdge: hex(0x000000, 0.3), tender: hex(0xe0ad45),
        tree: hex(0x3d4a35), treeShade: hex(0x2e3828), roof: hex(0x1d2228), roofRidge: hex(0x323a43),
        shadow: hex(0x000000, 0.45), ghost: .white.opacity(0.3),
        lamp: hex(0xf6c768))

    private static func hex(_ value: Int, _ alpha: Double = 1) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255,
              blue: Double(value & 0xff) / 255, opacity: alpha)
    }
}

/// Maps the design space onto the view: scale `k`, the harbour centred
/// horizontally, its top at the top of the view.
struct HarbourFrame {
    let k: CGFloat
    let origin: CGPoint

    init(k: CGFloat, viewWidth: CGFloat) {
        self.k = k
        origin = CGPoint(x: (viewWidth - HarbourGeometry.width * k) / 2, y: 0)
    }

    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * k, y: origin.y + p.y * k) }
    func x(_ x: CGFloat) -> CGFloat { origin.x + x * k }
    func y(_ y: CGFloat) -> CGFloat { origin.y + y * k }
    func scenePoint(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - origin.x) / k, y: (p.y - origin.y) / k) }
}

/// What the scenery needs to know about each berth.
struct BerthMark {
    let berth: Berth
    let moored: Bool
    /// The boat lies at anchor at this point, chain down to a buoy.
    let anchoredAt: CGPoint?
}

/// Everything that doesn't move, drawn like a calm nautical chart: shore
/// and quay, the sheltered basin, breakwaters, depth lines in the open sea,
/// piers, bollards and mooring lines. Drawn once per change.
enum HarbourScenery {
    static func draw(in context: inout GraphicsContext, size: CGSize, frame f: HarbourFrame,
                     layout: HarbourLayout, berths: [BerthMark], palette p: HarbourPalette) {
        let G = HarbourGeometry.self
        let wallY = layout.wallY, eastWall = layout.eastWall
        let quay = f.y(G.quayY)
        let full = CGRect(origin: .zero, size: size)

        // Open sea, deepening away from the harbour.
        context.fill(Path(full), with: .linearGradient(
            Gradient(colors: [p.sea, p.seaDeep]),
            startPoint: CGPoint(x: 0, y: f.y(wallY)), endPoint: CGPoint(x: 0, y: max(size.height, f.y(layout.height)))))
        drawContours(in: &context, size: size, frame: f, wallY: wallY, palette: p)

        // The sheltered basin inside the breakwaters, lighter and calm.
        var basin = Path()
        basin.move(to: CGPoint(x: f.x(G.wallX), y: quay))
        basin.addLine(to: CGPoint(x: f.x(G.wallX), y: f.y(wallY)))
        basin.addLine(to: CGPoint(x: f.x(G.wallEndX), y: f.y(wallY)))
        basin.addLine(to: f.point(CGPoint(x: G.mouthX, y: wallY + 4)))
        for point in eastWall.reversed() { basin.addLine(to: f.point(point)) }
        basin.closeSubpath()
        context.fill(basin, with: .linearGradient(Gradient(colors: [p.basinTop, p.basinBottom]),
                                                  startPoint: CGPoint(x: 0, y: quay), endPoint: CGPoint(x: 0, y: f.y(wallY))))

        // Shore: paving joints, a few trees, and the quay's ink edge.
        let shore = CGRect(x: 0, y: 0, width: size.width, height: quay)
        context.fill(Path(shore), with: .linearGradient(Gradient(colors: [p.shoreTop, p.shoreBottom]),
                                                        startPoint: .zero, endPoint: CGPoint(x: 0, y: quay)))
        var paving = Path()
        for x in stride(from: f.origin.x.truncatingRemainder(dividingBy: 24 * f.k) - 24 * f.k, to: size.width, by: 24 * f.k) {
            paving.move(to: CGPoint(x: x, y: quay - 22 * f.k))
            paving.addLine(to: CGPoint(x: x, y: quay - 3 * f.k))
        }
        paving.move(to: CGPoint(x: 0, y: quay - 22 * f.k))
        paving.addLine(to: CGPoint(x: size.width, y: quay - 22 * f.k))
        context.stroke(paving, with: .color(p.paving), lineWidth: 1)
        let lastQuayBerth = berths.filter { $0.berth.row == 0 }.map(\.berth.x).max() ?? 0
        drawTrees(in: &context, frame: f, clearOf: lastQuayBerth + 70, palette: p)
        context.fill(Path(CGRect(x: 0, y: quay - 2 * f.k, width: size.width, height: 4 * f.k)), with: .color(p.quayEdge))

        // The breakwaters: outlined stone with block joints along the crown.
        var walls = Path()
        walls.move(to: CGPoint(x: f.x(G.wallX), y: quay))
        walls.addLine(to: CGPoint(x: f.x(G.wallX), y: f.y(wallY)))
        walls.addLine(to: CGPoint(x: f.x(G.wallEndX), y: f.y(wallY)))
        walls.move(to: f.point(eastWall[0]))
        for point in eastWall.dropFirst() { walls.addLine(to: f.point(point)) }
        context.stroke(walls, with: .color(p.stoneEdge), style: StrokeStyle(lineWidth: 20 * f.k, lineCap: .round, lineJoin: .round))
        context.stroke(walls, with: .color(p.stone), style: StrokeStyle(lineWidth: 13 * f.k, lineCap: .round, lineJoin: .round))
        var joints = Path()
        for x in stride(from: G.wallX + 30, to: G.wallEndX - 8, by: 30) {
            joints.move(to: CGPoint(x: f.x(x), y: f.y(wallY - 4.5)))
            joints.addLine(to: CGPoint(x: f.x(x), y: f.y(wallY + 4.5)))
        }
        for y in stride(from: G.quayY + 30, to: wallY - 8, by: 30) {
            joints.move(to: CGPoint(x: f.x(G.wallX - 4.5), y: f.y(y)))
            joints.addLine(to: CGPoint(x: f.x(G.wallX + 4.5), y: f.y(y)))
            guard y < eastWall[1].y else { continue }
            joints.move(to: CGPoint(x: f.x(G.eastX - 4.5), y: f.y(y)))
            joints.addLine(to: CGPoint(x: f.x(G.eastX + 4.5), y: f.y(y)))
        }
        context.stroke(joints, with: .color(p.stoneEdge.opacity(0.2)), lineWidth: 1)
        // A light at each side of the mouth.
        for end in [CGPoint(x: G.wallEndX, y: wallY), eastWall[2]] {
            let at = f.point(end)
            context.fill(Path(ellipseIn: CGRect(x: at.x - 4 * f.k, y: at.y - 4 * f.k, width: 8 * f.k, height: 8 * f.k)),
                         with: .color(end.x < G.mouthX ? Color(red: 0.86, green: 0.42, blue: 0.38) : Color(red: 0.42, green: 0.7, blue: 0.5)))
        }

        // Finger piers either side of every berth, from the quay or the wall.
        var shadowed = context
        shadowed.addFilter(.shadow(color: p.shadow, radius: 2 * f.k, x: 0, y: 2 * f.k))
        for row in 0..<layout.rows {
            let xs = berths.filter { $0.berth.row == row }.map(\.berth.x)
            guard let first = xs.first, let last = xs.last else { continue }
            let length = G.boatLength + 6
            for x in stride(from: first - G.berthSpacing / 2, through: last + G.berthSpacing / 2 + 1, by: G.berthSpacing) {
                let top = row == 0 ? G.quayY : wallY - length
                let rect = CGRect(x: f.x(x - 3.5), y: f.y(top), width: 7 * f.k, height: length * f.k)
                shadowed.fill(Path(roundedRect: rect, cornerRadius: 1.5 * f.k), with: .color(p.wood))
            }
        }

        for mark in berths {
            let berth = mark.berth
            let onQuay = berth.row == 0
            // Two bollards per berth on the quay or the wall's crown.
            let bollardY = onQuay ? quay - 7 * f.k : f.y(wallY)
            let sternY = onQuay ? f.y(G.quayY + 9) : f.y(wallY - 13)
            for side: CGFloat in [-1, 1] {
                let bollard = CGPoint(x: f.x(berth.x + side * 17), y: bollardY)
                context.fill(Path(ellipseIn: CGRect(x: bollard.x - 3.5 * f.k, y: bollard.y - 3.5 * f.k,
                                                     width: 7 * f.k, height: 7 * f.k)), with: .color(p.quayEdge))
                if mark.moored {
                    let stern = CGPoint(x: f.x(berth.x + side * G.boatWidth * 0.34), y: sternY)
                    var line = Path()
                    line.move(to: bollard)
                    line.addQuadCurve(to: stern, control: CGPoint(x: (bollard.x + stern.x) / 2, y: (bollard.y + stern.y) / 2 + 3 * f.k))
                    context.stroke(line, with: .color(p.rope), lineWidth: 1.2 * f.k)
                }
            }
            if let lamp = p.lamp, onQuay {
                let at = CGPoint(x: f.x(berth.x), y: quay - 14 * f.k)
                var glow = context
                glow.addFilter(.blur(radius: 7 * f.k))
                glow.fill(Path(ellipseIn: CGRect(x: at.x - 11 * f.k, y: at.y - 11 * f.k, width: 22 * f.k, height: 22 * f.k)),
                          with: .color(lamp.opacity(0.5)))
                context.fill(Path(ellipseIn: CGRect(x: at.x - 2.5 * f.k, y: at.y - 2.5 * f.k, width: 5 * f.k, height: 5 * f.k)),
                             with: .color(lamp))
            }
            // An empty berth shows where its boat will lie.
            if !mark.moored {
                let center = f.point(layout.mooredCenter(berth))
                let outline = BoatHull().path(in: CGRect(x: -G.boatLength / 2 * f.k, y: -G.boatWidth / 2 * f.k,
                                                         width: G.boatLength * f.k, height: G.boatWidth * f.k))
                    .applying(CGAffineTransform(rotationAngle: onQuay ? .pi / 2 : -.pi / 2))
                    .applying(CGAffineTransform(translationX: center.x, y: center.y))
                context.stroke(outline, with: .color(p.ghost),
                               style: StrokeStyle(lineWidth: 1.2 * f.k, dash: [4 * f.k, 4 * f.k]))
            }
            // A boat at anchor: chain from the bow to a buoy.
            if let anchored = mark.anchoredAt {
                let bow = f.point(CGPoint(x: anchored.x + G.boatLength / 2 - 3, y: anchored.y))
                let buoy = CGPoint(x: bow.x + 22 * f.k, y: bow.y + 5 * f.k)
                var chain = Path()
                chain.move(to: bow)
                chain.addQuadCurve(to: buoy, control: CGPoint(x: bow.x + 12 * f.k, y: bow.y + 8 * f.k))
                context.stroke(chain, with: .color(p.rope.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.2 * f.k, dash: [2.5 * f.k, 2 * f.k]))
                let ring = Path(ellipseIn: CGRect(x: buoy.x - 4.5 * f.k, y: buoy.y - 4.5 * f.k, width: 9 * f.k, height: 9 * f.k))
                context.fill(ring, with: .color(p.tender))
                context.stroke(ring, with: .color(p.quayEdge.opacity(0.5)), lineWidth: 0.8 * f.k)
            }
        }
    }

    /// Depth lines in the open sea, as a chart draws them: each one follows
    /// the shape of the harbour a little further out, fainter as it deepens.
    private static func drawContours(in context: inout GraphicsContext, size: CGSize, frame f: HarbourFrame,
                                     wallY: CGFloat, palette p: HarbourPalette) {
        let G = HarbourGeometry.self
        for (i, depth) in [26, 54, 92, 140].enumerated() {
            let d = CGFloat(depth)
            let y = wallY + d
            var line = Path()
            let left = -f.origin.x / f.k - 20, right = (size.width - f.origin.x) / f.k + 20
            line.move(to: f.point(CGPoint(x: left, y: y + 6)))
            // Swing round below the harbour mouth, where the channel is dredged deeper.
            line.addCurve(to: f.point(CGPoint(x: G.mouthX - 90 - d * 0.3, y: y)),
                          control1: f.point(CGPoint(x: left + 200, y: y + 10)),
                          control2: f.point(CGPoint(x: G.mouthX - 260, y: y - 4)))
            line.addCurve(to: f.point(CGPoint(x: G.mouthX + 120 + d * 0.3, y: y - 6)),
                          control1: f.point(CGPoint(x: G.mouthX - 30, y: y + 20 + d * 0.15)),
                          control2: f.point(CGPoint(x: G.mouthX + 40, y: y + 16 + d * 0.15)))
            line.addCurve(to: f.point(CGPoint(x: right, y: y - 16)),
                          control1: f.point(CGPoint(x: G.mouthX + 220, y: y - 14)),
                          control2: f.point(CGPoint(x: right - 80, y: y - 12)))
            let opacity = 1 - Double(i) * 0.2
            context.stroke(line, with: .color(p.contour.opacity(opacity)),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: i == 3 ? [5, 4] : []))
        }
    }

    /// A short row of trees at the back of the shore, east of the berths and
    /// clear of their names.
    private static func drawTrees(in context: inout GraphicsContext, frame f: HarbourFrame, clearOf minX: CGFloat,
                                  palette p: HarbourPalette) {
        let trees: [(CGFloat, CGFloat, CGFloat)] = [(742, 30, 13), (772, 22, 10), (800, 32, 14), (834, 24, 11),
                                                     (866, 33, 13), (900, 25, 10), (930, 31, 12)]
        for (x, y, r) in trees where x - r > minX {
            let c = f.point(CGPoint(x: x, y: y))
            let rect = CGRect(x: c.x - r * f.k, y: c.y - r * f.k, width: 2 * r * f.k, height: 2 * r * f.k)
            var shaded = context
            shaded.addFilter(.shadow(color: p.shadow.opacity(0.6), radius: 2 * f.k, x: 2 * f.k, y: 3 * f.k))
            shaded.fill(Path(ellipseIn: rect), with: .color(p.treeShade))
            context.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.18 * f.k, dy: r * 0.18 * f.k)
                .offsetBy(dx: -r * 0.12 * f.k, dy: -r * 0.12 * f.k)), with: .color(p.tree))
        }
    }
}

/// A boat seen from above with its bow to the right: square stern, a hull
/// that narrows to a point.
struct BoatHull: Shape {
    func path(in rect: CGRect) -> Path {
        let l = rect.width / 2, w = rect.height / 2, c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(w * 0.35, 8)
        var p = Path()
        p.move(to: CGPoint(x: c.x - l, y: c.y - w + r))
        p.addQuadCurve(to: CGPoint(x: c.x - l + r, y: c.y - w), control: CGPoint(x: c.x - l, y: c.y - w))
        p.addLine(to: CGPoint(x: c.x + l * 0.28, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x + l, y: c.y), control: CGPoint(x: c.x + l * 0.88, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x + l * 0.28, y: c.y + w), control: CGPoint(x: c.x + l * 0.88, y: c.y + w))
        p.addLine(to: CGPoint(x: c.x - l + r, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x - l, y: c.y + w - r), control: CGPoint(x: c.x - l, y: c.y + w))
        p.closeSubpath()
        return p
    }
}
