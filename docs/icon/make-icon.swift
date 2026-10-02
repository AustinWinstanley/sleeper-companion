// Generates the app icon (light, dark and tinted variants) plus a preview sheet.
// Usage: swiftc -O make-icon.swift -o make-icon && ./make-icon
// then copy AppIcon*.png into App/Assets.xcassets/AppIcon.appiconset/.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    return CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xff) / 255, CGFloat((hex >> 8) & 0xff) / 255, CGFloat(hex & 0xff) / 255, alpha])!
}
let accent: UInt32 = 0x3ddc84
let deep: UInt32 = 0x0e2a1b

func makeContext(_ width: Int, _ height: Int) -> CGContext {
    return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                     space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func save(_ context: CGContext, _ name: String) {
    let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}
func roundedRect(_ context: CGContext, _ rect: CGRect, _ radius: CGFloat, _ fill: CGColor) {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(fill)
    context.fillPath()
}

let yellow: UInt32 = 0xf2a900
let blue: UInt32 = 0x2f7bff

enum TeamMark {
    case bolt
    case star
}

func polygon(_ context: CGContext, _ points: [(CGFloat, CGFloat)], _ fill: CGColor) {
    context.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() {
        context.addLine(to: CGPoint(x: point.0, y: point.1))
    }
    context.closePath()
    context.setFillColor(fill)
    context.fillPath()
}

/// Modern side-on helmet facing right, centered near the origin. Longer than it is tall,
/// with a flat crown, an overhanging brow, a jaw flap that comes forward, and a rear
/// lip that steps inward toward the neck. `hole` is the color showing through vents.
func helmet(_ context: CGContext, hole: CGColor, mark: TeamMark) {
    context.saveGState()
    context.translateBy(x: -8, y: -16)

    let shell = CGMutablePath()
    shell.move(to: CGPoint(x: -72, y: -62))                                    // rear base, tucked in toward the neck
    shell.addCurve(to: CGPoint(x: -85, y: -30), control1: CGPoint(x: -78, y: -54), control2: CGPoint(x: -84, y: -42))    // lip below the step
    shell.addLine(to: CGPoint(x: -95, y: -22))                                  // step: the shell above sits proud of the lip
    shell.addCurve(to: CGPoint(x: -60, y: 82), control1: CGPoint(x: -104, y: 16), control2: CGPoint(x: -90, y: 60))      // back of the dome
    shell.addCurve(to: CGPoint(x: 10, y: 106), control1: CGPoint(x: -42, y: 98), control2: CGPoint(x: -16, y: 106))      // crown
    shell.addCurve(to: CGPoint(x: 86, y: 46), control1: CGPoint(x: 50, y: 106), control2: CGPoint(x: 80, y: 80))         // forehead
    shell.addLine(to: CGPoint(x: 84, y: 28))                                    // brow face
    shell.addLine(to: CGPoint(x: 42, y: 24))                                    // brow underside
    shell.addCurve(to: CGPoint(x: 24, y: -18), control1: CGPoint(x: 30, y: 16), control2: CGPoint(x: 22, y: 0))          // opening edge
    shell.addCurve(to: CGPoint(x: 50, y: -46), control1: CGPoint(x: 26, y: -32), control2: CGPoint(x: 38, y: -40))       // jaw flap forward
    shell.addLine(to: CGPoint(x: 40, y: -68))                                   // flap tip
    shell.addCurve(to: CGPoint(x: -72, y: -62), control1: CGPoint(x: 0, y: -76), control2: CGPoint(x: -50, y: -72))      // neck line
    shell.closeSubpath()
    context.addPath(shell)
    context.setFillColor(color(0xffffff))
    context.fillPath()

    // Decal and vents, clipped to the shell.
    context.saveGState()
    context.addPath(shell)
    context.clip()
    switch mark {
    case .bolt:
        polygon(context, [(6, 88), (-38, 38), (-14, 38), (-28, 4), (22, 54), (-4, 54)], color(yellow))
    case .star:
        var points: [(CGFloat, CGFloat)] = []
        for index in 0..<10 {
            let radius: CGFloat = index % 2 == 0 ? 40 : 16
            let angle = CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            points.append((-10 + radius * cos(angle), 44 + radius * sin(angle)))
        }
        polygon(context, points, color(blue))
    }
    // Angular vents: one high at the back, one slim slot at ear level, one small by the brow.
    polygon(context, [(-72, 58), (-52, 76), (-47, 68), (-66, 52)], hole)
    polygon(context, [(-48, -14), (0, -6), (-10, -17), (-44, -23)], hole)
    polygon(context, [(50, 76), (68, 60), (62, 55), (45, 70)], hole)
    context.restoreGState()

    // Facemask: reaches well forward of the shell. Top bar from the brow, a tall front
    // upright, the bottom bar back to the jaw flap, two crossbars and one inner upright.
    context.setStrokeColor(color(0xffffff))
    context.setLineWidth(9)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 78, y: 30))
    context.addLine(to: CGPoint(x: 110, y: -2))
    context.addLine(to: CGPoint(x: 114, y: -62))
    context.addLine(to: CGPoint(x: 42, y: -62))
    context.strokePath()
    context.move(to: CGPoint(x: 112, y: -24))
    context.addLine(to: CGPoint(x: 30, y: -22))
    context.strokePath()
    context.move(to: CGPoint(x: 82, y: -23))
    context.addLine(to: CGPoint(x: 84, y: -61))
    context.strokePath()
    context.restoreGState()
}

func drawIcon(_ context: CGContext, top: UInt32 = 0x1c5c38, bottom: UInt32 = 0x0a1610) {
    let gradient = CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
    let gap: CGFloat = 48, side: CGFloat = (640 - gap) / 2, origin: CGFloat = 192
    let top = origin + side + gap
    roundedRect(context, CGRect(x: origin, y: top, width: side, height: side), 70, color(0xffffff, 0.22))
    roundedRect(context, CGRect(x: origin + side + gap, y: top, width: side, height: side), 70, color(0xffffff, 0.22))
    roundedRect(context, CGRect(x: origin, y: origin, width: 640, height: side), 70, color(0xffffff, 0.22))
    roundedRect(context, CGRect(x: origin + 56, y: origin + side - 122, width: 360, height: 44), 22, color(blue))
    roundedRect(context, CGRect(x: origin + 56, y: origin + 78, width: 230, height: 44), 22, color(yellow))

    // Left helmet faces right, right helmet is mirrored to face it.
    context.saveGState()
    context.translateBy(x: origin + side / 2, y: top + side / 2)
    context.scaleBy(x: 1.0, y: 1.0)
    helmet(context, hole: color(0x3d5a49), mark: .star)
    context.restoreGState()
    context.saveGState()
    context.translateBy(x: origin + side + gap + side / 2, y: top + side / 2)
    context.scaleBy(x: -1.0, y: 1.0)
    helmet(context, hole: color(0x3d5a49), mark: .bolt)
    context.restoreGState()
}

let icon = makeContext(1024, 1024)
drawIcon(icon)
save(icon, "AppIcon.png")

// Dark appearance: same artwork on a near-black field.
let dark = makeContext(1024, 1024)
drawIcon(dark, top: 0x14241b, bottom: 0x050807)
save(dark, "AppIcon-dark.png")

// Tinted appearance: iOS wants grayscale and applies the user's tint itself.
let gray = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
gray.draw(dark.makeImage()!, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
save(gray, "AppIcon-tinted.png")

// Preview: large with the iOS mask, plus Home Screen size (60 pt at 2x) to check legibility.
let sheet = makeContext(1540, 620)
sheet.setFillColor(color(0xf2f2f7)); sheet.fill(CGRect(x: 0, y: 0, width: 1540, height: 620))
let image = icon.makeImage()!
for (rect) in [CGRect(x: 40, y: 90, width: 440, height: 440), CGRect(x: 530, y: 330, width: 120, height: 120), CGRect(x: 530, y: 170, width: 80, height: 80)] {
    sheet.saveGState()
    sheet.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil))
    sheet.clip()
    sheet.interpolationQuality = .high
    sheet.draw(image, in: rect)
    sheet.restoreGState()
}
sheet.saveGState()
sheet.clip(to: CGRect(x: 700, y: 150, width: 800, height: 400))
sheet.draw(image, in: CGRect(x: 700 - 172 * 1.18, y: 150 - 516 * 1.18, width: 1024 * 1.18, height: 1024 * 1.18))
sheet.restoreGState()
save(sheet, "helmets-preview.png")
