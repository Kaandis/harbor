// Draws Harbor's app icon: a marina seen from above and turned on the
// diagonal. Boats lie tied in rows along a pier in sheltered water, and a
// breakwater wraps the basin and runs on out into the deeper sea. The cream
// shore is the cream the Harbor apps share.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-out")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath
}

let ink = 0x231f1c, cream = 0xfffbf6, wood = 0xc9a079, deck = 0xe6cfae
let basin = 0x5fb3c1, openSea = 0x3f8fb0, stone = 0xf3e6d4
let waterShadow = color(0x0b3a44, 0.35)

/// A boat from above: square stern at the pier, pointed bow, a deck inset
/// and a soft shadow on the water. The bow points along `angle`.
func boat(_ cg: CGContext, _ center: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat) {
    func hull(_ l: CGFloat, _ w: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -l, y: -w + 6))
        p.addQuadCurve(to: CGPoint(x: -l + 6, y: -w), control: CGPoint(x: -l, y: -w))
        p.addLine(to: CGPoint(x: l * 0.3, y: -w))
        p.addQuadCurve(to: CGPoint(x: l, y: 0), control: CGPoint(x: l * 0.85, y: -w))
        p.addQuadCurve(to: CGPoint(x: l * 0.3, y: w), control: CGPoint(x: l * 0.85, y: w))
        p.addLine(to: CGPoint(x: -l + 6, y: w))
        p.addQuadCurve(to: CGPoint(x: -l, y: w - 6), control: CGPoint(x: -l, y: w))
        p.closeSubpath()
        return p
    }
    cg.saveGState()
    cg.translateBy(x: center.x, y: center.y)
    cg.rotate(by: angle)
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 10, color: waterShadow)
    cg.addPath(hull(length / 2, width / 2))
    cg.setFillColor(color(cream))
    cg.fillPath()
    cg.setShadow(offset: .zero, blur: 0, color: nil)
    cg.translateBy(x: -length * 0.06, y: 0)
    cg.addPath(hull(length * 0.3, width * 0.26))
    cg.setFillColor(color(deck))
    cg.fillPath()
    cg.restoreGState()
}

func pier(_ cg: CGContext, _ rect: CGRect) {
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 6, color: color(0x0b3a44, 0.3))
    cg.setFillColor(color(wood))
    cg.fill(rect)
    cg.restoreGState()
}

func draw(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // Body.
    let bodyPath = rounded(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.22))
    cg.addPath(bodyPath)
    cg.setFillColor(color(0xf6e7d6))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()

    // The scene is drawn upright, then turned and scaled to sit in the body.
    cg.translateBy(x: 530, y: 500)
    cg.rotate(by: 0.32)
    cg.scaleBy(x: 0.84, y: 0.84)
    cg.translateBy(x: -512, y: -512)

    // Open sea, and the calmer water the breakwater shelters.
    cg.setFillColor(color(openSea))
    cg.fill(CGRect(x: -600, y: -600, width: 2200, height: 1400))
    let sheltered = CGMutablePath()
    sheltered.addLines(between: [CGPoint(x: 150, y: 800), CGPoint(x: 150, y: 270),
                                 CGPoint(x: 1240, y: 120), CGPoint(x: 1240, y: 800)])
    cg.addPath(sheltered)
    cg.setFillColor(color(basin))
    cg.fillPath()

    // The shore, with an ink quay edge.
    let shore = CGPath(rect: CGRect(x: -600, y: 780, width: 2200, height: 1600), transform: nil)
    cg.saveGState()
    cg.addPath(shore)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xfdf3e8), color(0xf1dfc8)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100),
                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    cg.restoreGState()
    cg.addPath(shore)
    cg.setStrokeColor(color(ink))
    cg.setLineWidth(14)
    cg.strokePath()

    // The breakwater: outlined stone, wrapping the basin and running out to sea.
    let wall = CGMutablePath()
    wall.move(to: CGPoint(x: 150, y: 790))
    wall.addLine(to: CGPoint(x: 150, y: 270))
    wall.addLine(to: CGPoint(x: 1240, y: 120))
    cg.setLineJoin(.round)
    cg.setLineCap(.round)
    cg.addPath(wall)
    cg.setStrokeColor(color(ink))
    cg.setLineWidth(78)
    cg.strokePath()
    cg.addPath(wall)
    cg.setStrokeColor(color(stone))
    cg.setLineWidth(50)
    cg.strokePath()

    // A pier from the shore with two arms, boats tied in rows beneath each.
    pier(cg, CGRect(x: 476, y: 360, width: 40, height: 422))
    for y: CGFloat in [640, 470] {
        pier(cg, CGRect(x: 240, y: y, width: 510, height: 28))
        for x: CGFloat in [300, 400, 592, 692] {
            boat(cg, CGPoint(x: x, y: y - 66), length: 124, width: 56, angle: -.pi / 2)
        }
    }
    cg.restoreGState()

    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = out.appendingPathComponent("AppIcon.appiconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)@\(scale)x.png"
        try! draw(size: base * scale).write(to: iconset.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
try! draw(size: 512).write(to: out.appendingPathComponent("icon.png"))
try! draw(size: 180).write(to: out.appendingPathComponent("apple-touch-icon.png"))
try! draw(size: 64).write(to: out.appendingPathComponent("favicon.png"))
print("wrote \(out.path)")
