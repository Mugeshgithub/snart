// Based on Cicada (https://github.com/wquguru/cicada), Apache License 2.0.
// Modified by CognivexAI, 2026.
// Renders the app icon (the CognivexAI rings on a navy squircle)
// into an .iconset. `CicadaIcon [--dev] <out.iconset>`; --dev adds a "DEV" band.
import AppKit

let navy = NSColor(srgbRed: 0.118, green: 0.161, blue: 0.231, alpha: 1)   // #1E293B
let ink = NSColor(srgbRed: 0.082, green: 0.09, blue: 0.11, alpha: 1)     // #15171C

// A copy of CicadaLogo in Sources/Cicada/Onboarding.swift (this target can't import the app);
// keep it, that file and site/icon.svg in step.
enum CicadaLogo {
    static let orange = rgb(0xEA580C)
    static let ink = rgb(0x15171C)
    static let white = CGColor(gray: 1, alpha: 1)

    static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    static func gradient(_ stops: [(UInt32, CGFloat)], at locations: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map { rgb($0.0, $0.1) } as CFArray,
                   locations: locations)!
    }
    static func circle(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        c.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    /// A ring stroked with a diagonal gradient, as in the CognivexAI mark.
    static func ring(_ c: CGContext, r: CGFloat, width: CGFloat, _ g: CGGradient, from: CGPoint, to: CGPoint) {
        c.saveGState()
        circle(c, 50, 50, r); c.setLineWidth(width); c.replacePathWithStrokedPath(); c.clip()
        c.drawLinearGradient(g, start: from, end: to, options: [])
        c.restoreGState()
    }

    /// The CognivexAI mark (blue outer ring, orange inner ring, white core) on a navy squircle.
    /// `unit` is device pixels per design unit (shadows are in device space).
    static func drawIcon(_ c: CGContext, unit: CGFloat) {
        c.saveGState()
        c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 100, height: 100), cornerWidth: 23, cornerHeight: 23, transform: nil))
        c.clip()
        c.drawLinearGradient(gradient([(0x1E293B, 1), (0x0B1120, 1)], at: [0, 1]),
                             start: .zero, end: CGPoint(x: 100, y: 100), options: [])
        ring(c, r: 31, width: 6.5, gradient([(0x60A5FA, 1), (0x3B82F6, 1), (0x1D4ED8, 1)], at: [0, 0.4, 1]),
             from: CGPoint(x: 19, y: 19), to: CGPoint(x: 81, y: 81))
        ring(c, r: 19, width: 6.5, gradient([(0xF97316, 1), (0xEA580C, 1), (0xB91C1C, 1)], at: [0, 0.4, 1]),
             from: CGPoint(x: 69, y: 31), to: CGPoint(x: 31, y: 69))
        c.saveGState()
        circle(c, 50, 50, 8.5); c.clip()
        c.drawRadialGradient(gradient([(0xFFFFFF, 1), (0xE2E8F0, 1)], at: [0.5, 1]), startCenter: CGPoint(x: 50, y: 50),
                             startRadius: 0, endCenter: CGPoint(x: 50, y: 50), endRadius: 8.5, options: [])
        c.restoreGState()
        c.restoreGState()
    }

    /// One colour for the menu bar: the two rings and the core.
    static func drawTemplate(_ c: CGContext, color: CGColor) {
        c.setStrokeColor(color); c.setFillColor(color)
        c.setLineWidth(9); circle(c, 50, 55, 34); c.strokePath()
        c.setLineWidth(9); circle(c, 50, 55, 17); c.strokePath()
        circle(c, 50, 55, 6); c.fillPath()
    }
}

/// `ios`: the iPhone and iPad icon, a full-bleed opaque square (the system draws the corners and
/// App Store Connect refuses an alpha channel); otherwise the macOS grid with its margin and shadow.
func render(_ px: Int, dev: Bool, ios: Bool = false) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    // macOS icon grid: an 824 pt body inset 100 pt, corner ≈ 185 pt.
    // iOS: the body overflows the canvas by 80 pt a side, so the logo's own rounded tile reaches
    // past every corner and the system's mask is the only rounding.
    let body = ios ? NSRect(x: -80 * s, y: -80 * s, width: 1184 * s, height: 1184 * s) : NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let squircle = ios ? NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024 * s, height: 1024 * s))
        : NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    if !ios {
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 20 * s
        shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.set()
    }
    navy.setFill()
    squircle.fill()
    NSShadow().set()

    // Design space is the 100-unit logo, y down, mapped onto the body.
    let c = NSGraphicsContext.current!.cgContext
    c.saveGState()
    c.translateBy(x: body.minX, y: body.maxY)
    c.scaleBy(x: body.width / 100, y: -body.height / 100)
    CicadaLogo.drawIcon(c, unit: body.width / 100)
    c.restoreGState()

    if dev {
        // Dev builds: a dark "DEV" band across the bottom, so the Dock, Finder and
        // Spotlight tell them apart from the installed app.
        NSGraphicsContext.saveGraphicsState()
        squircle.addClip()
        ink.setFill()
        let band = ios ? NSRect(x: 0, y: 0, width: 1024 * s, height: 190 * s) : NSRect(x: body.minX, y: body.minY, width: body.width, height: 170 * s)
        band.fill()
        let font = NSFont.systemFont(ofSize: 110 * s, weight: .heavy)
        let text = NSAttributedString(string: "DEV", attributes: [
            .font: font, .foregroundColor: NSColor.white, .kern: 14 * s,
        ])
        let size = text.size()
        text.draw(at: NSPoint(x: band.midX - size.width / 2 + 7 * s, y: band.minY + (band.height - size.height) / 2 + 6 * s))
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.restoreGraphicsState()
    if ios, let image = rep.cgImage,
       let opaque = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) {
        // Drawn again without an alpha channel: a fully opaque RGBA PNG is still refused.
        opaque.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
        if let flat = opaque.makeImage() { return NSBitmapImageRep(cgImage: flat).representation(using: .png, properties: [:])! }
    }
    return rep.representation(using: .png, properties: [:])!
}

let args = Array(CommandLine.arguments.dropFirst())
let dev = args.contains("--dev")
// --ios <file.png>: the 1024 px iOS icon only (ios/scripts/build.sh).
if let i = args.firstIndex(of: "--ios"), i + 1 < args.count {
    try render(1024, dev: dev, ios: true).write(to: URL(fileURLWithPath: args[i + 1]))
    exit(0)
}
let out = URL(fileURLWithPath: args.first { $0 != "--dev" } ?? "AppIcon.iconset")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try render(size, dev: dev).write(to: out.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2, dev: dev).write(to: out.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
