import SwiftUI

/// The Drift brand mark (design option 23a, final): five peer nodes linked to a
/// coral center, bold lines filling the squircle. Scales to any square frame.
struct DriftLogoMark: View {
    var background: Color? = Color(red: 0x3D / 255, green: 0x35 / 255, blue: 0x27 / 255)

    private static let nodes: [CGPoint] = {
        let raw: [CGPoint] = [CGPoint(x: 100, y: 20), CGPoint(x: 172, y: 60), CGPoint(x: 146, y: 152), CGPoint(x: 54, y: 152), CGPoint(x: 28, y: 60)]
        let angle = -14 * CGFloat.pi / 180
        let networkScale: CGFloat = 0.84
        return raw.map { p in
            let dx = p.x - 100, dy = p.y - 100
            let rx = dx * cos(angle) - dy * sin(angle)
            let ry = dx * sin(angle) + dy * cos(angle)
            return CGPoint(x: 100 + rx * networkScale, y: 100 + ry * networkScale)
        }
    }()

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let scale = side / 200
            let offset = (min(size.width, size.height) - 200 * scale) / 2
            func mpt(_ p: CGPoint) -> CGPoint { CGPoint(x: offset + p.x * scale, y: offset + p.y * scale) }
            let mcenter = mpt(CGPoint(x: 100, y: 100))

            if let background {
                // 23b fills the squircle almost edge-to-edge, clipping whatever spills past the corners.
                context.clip(to: Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: side * 0.226))
                context.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: side * 0.226), with: .color(background))
            }

            var spokes = Path()
            for node in Self.nodes {
                spokes.move(to: mcenter)
                spokes.addLine(to: mpt(node))
            }
            context.stroke(spokes, with: .color(Color(red: 0x7A / 255, green: 0x6E / 255, blue: 0x58 / 255)), style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round))

            let nodeColor = Color(red: 0xFB / 255, green: 0xF4 / 255, blue: 0xE9 / 255)
            for node in Self.nodes {
                let c = mpt(node); let r = 15 * scale
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(nodeColor))
            }
            let r = 26 * scale
            context.fill(Path(ellipseIn: CGRect(x: mcenter.x - r, y: mcenter.y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The sidebar wordmark (design option 26c): a flat, backgroundless network mark
/// paired with the "Drift" title, sized so the icon reads clearly larger than the text.
struct DriftSidebarMark: View {
    private static let nodes: [CGPoint] = {
        let raw: [CGPoint] = [CGPoint(x: 100, y: 32), CGPoint(x: 158, y: 68), CGPoint(x: 138, y: 148), CGPoint(x: 62, y: 148), CGPoint(x: 42, y: 68)]
        let angle = -14 * CGFloat.pi / 180
        return raw.map { p in
            let dx = p.x - 100, dy = p.y - 100
            return CGPoint(x: 100 + dx * cos(angle) - dy * sin(angle), y: 100 + dx * sin(angle) + dy * cos(angle))
        }
    }()

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            func pt(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scale, y: p.y * scale) }
            let center = pt(CGPoint(x: 100, y: 100))

            var spokes = Path()
            for node in Self.nodes {
                spokes.move(to: center)
                spokes.addLine(to: pt(node))
            }
            context.stroke(spokes, with: .color(Color(red: 0x7A / 255, green: 0x6E / 255, blue: 0x58 / 255)), style: StrokeStyle(lineWidth: 13 * scale, lineCap: .round))

            let nodeColor = Color(red: 0xF3 / 255, green: 0xEE / 255, blue: 0xE3 / 255)
            for node in Self.nodes {
                let c = pt(node); let r: CGFloat = 15 * scale
                context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(nodeColor))
            }
            let r: CGFloat = 26 * scale
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 0xD9 / 255, green: 0x77 / 255, blue: 0x57 / 255)))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
