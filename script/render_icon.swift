// Renders the Swarm app icon (design option 22a: final peer-network mark, network
// nodes +10%, on a warm dark squircle) into an .iconset at all macOS sizes.
// Run via script/make_icon.sh.
import AppKit

let iconsetPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Swarm.iconset"

struct Mark {
    // Geometry in the design's 200x200 viewBox, center (100,100): rotate(-14deg). The 23a SVG
    // renders at 168/200 (0.84x), exactly filling the box with no overflow clipping needed.
    static let nodes: [(x: CGFloat, y: CGFloat)] = [(100, 20), (172, 60), (146, 152), (54, 152), (28, 60)]
    static let rotation: CGFloat = -14 * .pi / 180
    static let networkScale: CGFloat = 0.84
    static let spokeWidth: CGFloat = 8
    static let nodeRadius: CGFloat = 15
    static let centerRadius: CGFloat = 26
    static let background = NSColor(srgbRed: 0x3D / 255, green: 0x35 / 255, blue: 0x27 / 255, alpha: 1)
    static let spoke = NSColor(srgbRed: 0x7A / 255, green: 0x6E / 255, blue: 0x58 / 255, alpha: 1)
    static let node = NSColor(srgbRed: 0xFB / 255, green: 0xF4 / 255, blue: 0xE9 / 255, alpha: 1)
    static let center = NSColor(srgbRed: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255, alpha: 1)
}

func rotated(_ point: (x: CGFloat, y: CGFloat)) -> CGPoint {
    let dx = point.x - 100, dy = point.y - 100
    let rx = dx * cos(Mark.rotation) - dy * sin(Mark.rotation)
    let ry = dx * sin(Mark.rotation) + dy * cos(Mark.rotation)
    return CGPoint(x: 100 + rx * Mark.networkScale, y: 100 + ry * Mark.networkScale)
}

func render(canvas: Int) -> NSImage {
    let size = CGFloat(canvas)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocusFlipped(true)
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

    // Apple icon grid: squircle occupies 824/1024 of the canvas, radius ~185/824.
    let inset = size * 100 / 1024
    let box = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let squircle = CGPath(roundedRect: box, cornerWidth: box.width * 185 / 824, cornerHeight: box.width * 185 / 824, transform: nil)
    ctx.addPath(squircle)
    ctx.setFillColor(Mark.background.cgColor)
    ctx.fillPath()

    // 23b fills the squircle almost edge-to-edge (design's 180/200 svg-to-box ratio), clipping
    // whatever spills past the corners — so the mark scale tracks the box itself, not a smaller block.
    ctx.addPath(squircle)
    ctx.clip()
    let scale = box.width / 200
    let origin = (size - 200 * scale) / 2
    func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: origin + p.x * scale, y: origin + p.y * scale) }
    let centerPt = pt(CGPoint(x: 100, y: 100))

    ctx.setStrokeColor(Mark.spoke.cgColor)
    ctx.setLineWidth(Mark.spokeWidth * scale)
    ctx.setLineCap(.round)
    for node in Mark.nodes {
        ctx.move(to: centerPt)
        ctx.addLine(to: pt(rotated(node)))
    }
    ctx.strokePath()

    ctx.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 4.8 * scale, color: NSColor.black.withAlphaComponent(0.4).cgColor)
    ctx.setFillColor(Mark.node.cgColor)
    for node in Mark.nodes {
        let c = pt(rotated(node)); let r = Mark.nodeRadius * scale
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
    ctx.setFillColor(Mark.center.cgColor)
    let r = Mark.centerRadius * scale
    ctx.fillEllipse(in: CGRect(x: centerPt.x - r, y: centerPt.y - r, width: r * 2, height: r * 2))

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
let master = render(canvas: 1024)
for base in [16, 32, 128, 256, 512] {
    writePNG(master, pixels: base, to: "\(iconsetPath)/icon_\(base)x\(base).png")
    writePNG(master, pixels: base * 2, to: "\(iconsetPath)/icon_\(base)x\(base)@2x.png")
}
print("iconset written to \(iconsetPath)")
