// Draws Harbor's app icon: a harbour seen from above, two breakwater arms
// around a calm basin with three boats at the quay, on the cream squircle the
// Harbor apps share.
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

func draw(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    cg.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // Body.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = rounded(body, 185)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.22))
    cg.addPath(bodyPath)
    cg.setFillColor(color(0xf6e7d6))
    cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xfdf3e8), color(0xf1dfc8)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Seen from above: open sea at the top, a quay along the bottom, and two
    // breakwater arms holding a calm basin between them.
    cg.setFillColor(color(0x8fc3d6))
    cg.fill(CGRect(x: 100, y: 430, width: 824, height: 500))
    let basin = CGMutablePath()
    basin.move(to: CGPoint(x: 250, y: 430))
    basin.addLine(to: CGPoint(x: 250, y: 610))
    basin.addQuadCurve(to: CGPoint(x: 440, y: 716), control: CGPoint(x: 250, y: 716))
    basin.addLine(to: CGPoint(x: 584, y: 716))
    basin.addQuadCurve(to: CGPoint(x: 774, y: 610), control: CGPoint(x: 774, y: 716))
    basin.addLine(to: CGPoint(x: 774, y: 430))
    basin.closeSubpath()
    cg.addPath(basin)
    cg.setFillColor(color(0xc4e2ec))
    cg.fillPath()

    cg.setStrokeColor(color(0x231f1c))
    cg.setLineWidth(40)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    let left = CGMutablePath()
    left.move(to: CGPoint(x: 250, y: 430))
    left.addLine(to: CGPoint(x: 250, y: 610))
    left.addQuadCurve(to: CGPoint(x: 430, y: 716), control: CGPoint(x: 250, y: 716))
    cg.addPath(left)
    let right = CGMutablePath()
    right.move(to: CGPoint(x: 774, y: 430))
    right.addLine(to: CGPoint(x: 774, y: 610))
    right.addQuadCurve(to: CGPoint(x: 594, y: 716), control: CGPoint(x: 774, y: 716))
    cg.addPath(right)
    cg.strokePath()

    // The quay.
    cg.setFillColor(color(0x231f1c))
    cg.fill(CGRect(x: 100, y: 410, width: 824, height: 30))

    // Three boats moored bow-out, seen from above.
    func boat(at x: CGFloat, hull: Int, deck: Int) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 446))
        path.addLine(to: CGPoint(x: x, y: 560))
        path.addQuadCurve(to: CGPoint(x: x + 44, y: 636), control: CGPoint(x: x, y: 616))
        path.addQuadCurve(to: CGPoint(x: x + 88, y: 560), control: CGPoint(x: x + 88, y: 616))
        path.addLine(to: CGPoint(x: x + 88, y: 446))
        path.closeSubpath()
        cg.addPath(path)
        cg.setFillColor(color(hull))
        cg.fillPath()
        cg.setFillColor(color(deck))
        cg.addPath(rounded(CGRect(x: x + 22, y: 474, width: 44, height: 58), 14))
        cg.fillPath()
    }
    boat(at: 318, hull: 0xfffbf6, deck: 0x231f1c)
    boat(at: 468, hull: 0x231f1c, deck: 0xfffbf6)
    boat(at: 618, hull: 0xeadccb, deck: 0x231f1c)

    // A small lighthouse at the tip of the left arm.
    cg.setFillColor(color(0xfffbf6))
    cg.fillEllipse(in: CGRect(x: 404, y: 690, width: 52, height: 52))
    cg.setFillColor(color(0x231f1c))
    cg.fillEllipse(in: CGRect(x: 418, y: 704, width: 24, height: 24))
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
