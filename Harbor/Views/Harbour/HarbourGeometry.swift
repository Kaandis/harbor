import CoreGraphics

/// The harbour is laid out in a fixed design space 1000 points wide and
/// scaled to the window. The shore runs along the top. Two breakwaters
/// enclose the basin: one down the left and along the bottom, one down the
/// right, with the harbour mouth between their ends. Beyond lies the open
/// sea, where apps that aren't installed wait at anchor.
enum HarbourGeometry {
    static let width: CGFloat = 1000
    static let quayY: CGFloat = 88
    /// The fairway boats follow from the mouth to their berth.
    static let laneY: CGFloat = 250
    static let wallX: CGFloat = 46
    static let wallEndX: CGFloat = 700
    static let eastX: CGFloat = 944
    static let mouthX: CGFloat = 786

    static let boatLength: CGFloat = 112
    static let boatWidth: CGFloat = 50
    static let iconSize: CGFloat = 38
    static let tenderLength: CGFloat = 46
    static let tenderWidth: CGFloat = 22

    /// Room per berth, so boats never sit cheek by jowl.
    static let berthSpacing: CGFloat = 120
    /// Berths along the quay before a second row opens along the breakwater.
    static let quayBerths = 6

    /// The harbour master's office on the shore, which stands for Harbor itself.
    static let office = CGRect(x: 96, y: 20, width: 84, height: 50)
}

/// A berth: along the quay (row 0, bow toward the fairway) or, once the quay
/// is full, against the inside of the breakwater (row 1, facing the quay).
struct Berth: Equatable {
    let x: CGFloat
    let row: Int
}

/// Where everything goes for a given number of apps. One row of berths
/// along the quay holds six; past that the basin grows taller and a second
/// row lines the breakwater across the fairway.
struct HarbourLayout: Equatable {
    /// One berth per app, then one kept free for the next app.
    let berths: [Berth]
    let rows: Int

    init(apps: Int) {
        let G = HarbourGeometry.self
        let total = apps + 1
        let first = min(total, G.quayBerths)
        let second = total - first
        rows = second > 0 ? 2 : 1
        // The quay row centres on the basin; the breakwater row keeps clear
        // of the mouth.
        // Centred on the basin, but never under the office on the shore.
        let centre = (G.wallX + G.eastX) / 2
        let start = max(centre - G.berthSpacing * CGFloat(first - 1) / 2, 270)
        let quay = (0..<first).map { Berth(x: start + G.berthSpacing * CGFloat($0), row: 0) }
        let wall = (0..<second).map { Berth(x: 130 + G.berthSpacing * CGFloat($0), row: 1) }
        berths = quay + wall
    }

    var wallY: CGFloat { rows == 1 ? 304 : 420 }
    var seaY: CGFloat { wallY + 88 }
    var height: CGFloat { wallY + 166 }
    /// How much stays in view while a page is open: the shore, every berth
    /// and the fairway.
    var collapsedHeight: CGFloat { rows == 1 ? 278 : wallY + 16 }
    /// The right-hand breakwater: down from the shore, then angled in.
    var eastWall: [CGPoint] {
        [CGPoint(x: HarbourGeometry.eastX, y: HarbourGeometry.quayY),
         CGPoint(x: HarbourGeometry.eastX, y: wallY - 42), CGPoint(x: 872, y: wallY)]
    }

    /// A moored boat's centre: stern against the quay or the wall, bow to the fairway.
    func mooredCenter(_ berth: Berth) -> CGPoint {
        let G = HarbourGeometry.self
        return berth.row == 0
            ? CGPoint(x: berth.x, y: G.quayY + 6 + G.boatLength / 2)
            : CGPoint(x: berth.x, y: wallY - 10 - G.boatLength / 2)
    }

    /// The tip of a moored boat's bow, where captions and supply boats go.
    func bow(_ berth: Berth) -> CGPoint {
        let c = mooredCenter(berth), half = HarbourGeometry.boatLength / 2
        return CGPoint(x: c.x, y: berth.row == 0 ? c.y + half : c.y - half)
    }

    /// Where the `index`th app that isn't installed waits, in a line along the sea.
    func anchorage(index: Int) -> CGPoint {
        CGPoint(x: 150 + CGFloat(index % 5) * 150, y: seaY + CGFloat(index / 5) * 62)
    }

    /// In from the anchorage, through the mouth, along the fairway, and
    /// backed into the berth stern first, the way boats moor stern-to.
    func arrival(from index: Int, to berth: Berth) -> Voyage {
        let G = HarbourGeometry.self
        let anchor = anchorage(index: index)
        return Voyage(points: [anchor, CGPoint(x: G.mouthX, y: anchor.y), CGPoint(x: G.mouthX, y: G.laneY),
                               CGPoint(x: berth.x, y: G.laneY), mooredCenter(berth)],
                      reversesLastLeg: true)
    }

    /// A supply boat bringing an update in from the open sea to the moored
    /// boat's bow.
    func supply(to berth: Berth) -> Voyage {
        let G = HarbourGeometry.self
        let offset = G.tenderLength / 2 + 8
        let bow = self.bow(berth)
        let end = CGPoint(x: berth.x, y: berth.row == 0 ? bow.y + offset : bow.y - offset)
        return Voyage(points: [CGPoint(x: G.width + 60, y: seaY + 24), CGPoint(x: G.mouthX, y: seaY),
                               CGPoint(x: G.mouthX, y: G.laneY), CGPoint(x: berth.x, y: G.laneY), end],
                      reversesLastLeg: false)
    }
}

/// A route through the harbour, walked by a fraction of its length.
struct Voyage: Equatable {
    let points: [CGPoint]
    /// The boat backs along the last leg, bow pointing away from where it goes.
    let reversesLastLeg: Bool

    private var lengths: [CGFloat] {
        zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
    }

    func position(at t: CGFloat) -> CGPoint {
        let lengths = self.lengths
        let total = lengths.reduce(0, +)
        guard total > 0 else { return points.first ?? .zero }
        var remaining = min(max(t, 0), 1) * total
        for (i, length) in lengths.enumerated() {
            if remaining <= length || i == lengths.count - 1 {
                let f = length > 0 ? min(remaining / length, 1) : 1
                let a = points[i], b = points[i + 1]
                return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            }
            remaining -= length
        }
        return points.last ?? .zero
    }

    /// The bow's direction in radians. Looking a little behind and ahead
    /// turns the boat through each corner instead of snapping it round.
    func heading(at t: CGFloat) -> CGFloat {
        let window: CGFloat = 0.05
        let lastLegStart = lastLegFraction
        func direction(at s: CGFloat) -> CGVector {
            let s = min(max(s, 0), 1)
            let a = position(at: max(s - 0.002, 0)), b = position(at: min(s + 0.002, 1))
            var v = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            if reversesLastLeg && s > lastLegStart { v = CGVector(dx: -v.dx, dy: -v.dy) }
            let length = hypot(v.dx, v.dy)
            return length > 0 ? CGVector(dx: v.dx / length, dy: v.dy / length) : .zero
        }
        let behind = direction(at: t - window), ahead = direction(at: t + window)
        var v = CGVector(dx: behind.dx + ahead.dx, dy: behind.dy + ahead.dy)
        if hypot(v.dx, v.dy) < 0.01 { v = ahead }
        return atan2(v.dy, v.dx)
    }

    private var lastLegFraction: CGFloat {
        let lengths = self.lengths
        let total = lengths.reduce(0, +)
        guard total > 0, let last = lengths.last else { return 1 }
        return (total - last) / total
    }
}
