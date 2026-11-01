// Generates Infly's app icons and sample photos with CoreGraphics. Everything is drawn from code, so it's original.
// Usage: swift Tools/GenerateArt.swift   (run from the repository root)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconDir = root.appending(path: "Infly/Assets.xcassets/AppIcon.appiconset")
let sampleDir = root.appending(path: "Shared/Samples")

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Deterministic random numbers so the art is identical on every run.
struct Random {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
}

final class Canvas {
    let width: Int, height: Int
    let context: CGContext

    init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
        // Opaque, because the App Store rejects app icons that have an alpha channel.
        context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1) // y grows downward, like UIKit
    }

    var w: CGFloat { CGFloat(width) }
    var h: CGFloat { CGFloat(height) }

    func linear(_ colors: [CGColor], _ locations: [CGFloat]? = nil, from: CGPoint, to: CGPoint, clip: CGPath? = nil) {
        context.saveGState()
        if let clip { context.addPath(clip); context.clip() }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
        context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    func glow(_ color: CGColor, at center: CGPoint, radius: CGFloat) {
        let clear = color.copy(alpha: 0)!
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color, clear] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    func fill(_ path: CGPath, _ color: CGColor) {
        context.addPath(path)
        context.setFillColor(color)
        context.fillPath()
    }

    /// Film-like grain so the generated photos don't look flat.
    func grain(_ amount: Int, seed: UInt64) {
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return }
        var random = Random(state: seed)
        for i in 0..<(width * height) {
            let delta = Int(random.next() * CGFloat(amount * 2)) - amount
            for c in 0..<3 {
                let p = i * 4 + c
                data[p] = UInt8(clamping: Int(data[p]) + delta)
            }
        }
    }

    func save(_ url: URL, type: UTType, quality: CGFloat = 0.8) {
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        CGImageDestinationFinalize(destination)
        print("wrote", url.lastPathComponent)
    }
}

/// A mountain ridge by midpoint displacement, closed along the bottom edge.
func ridge(width: CGFloat, bottom: CGFloat, base: CGFloat, roughness: CGFloat, seed: UInt64) -> CGPath {
    var random = Random(state: seed)
    var heights: [CGFloat] = [base + (random.next() - 0.5) * roughness, base + (random.next() - 0.5) * roughness]
    var spread = roughness
    for _ in 0..<8 {
        var next: [CGFloat] = []
        for i in 0..<(heights.count - 1) {
            next.append(heights[i])
            next.append((heights[i] + heights[i + 1]) / 2 + (random.next() - 0.5) * spread)
        }
        next.append(heights[heights.count - 1])
        heights = next
        spread *= 0.55
    }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: bottom))
    for (i, y) in heights.enumerated() {
        path.addLine(to: CGPoint(x: width * CGFloat(i) / CGFloat(heights.count - 1), y: y))
    }
    path.addLine(to: CGPoint(x: width, y: bottom))
    path.closeSubpath()
    return path
}

// MARK: Icons

func drawIcon(_ style: String) -> Canvas {
    let canvas = Canvas(1024, 1024)
    let c = canvas.context
    switch style {
    case "dark":
        canvas.linear([rgb(0x1A1638), rgb(0x07070D)], from: .zero, to: CGPoint(x: 1024, y: 1024))
        canvas.glow(rgb(0x5B4CF0, 0.55), at: CGPoint(x: 820, y: 900), radius: 620)
    case "tinted":
        canvas.linear([rgb(0x202020), rgb(0x000000)], from: .zero, to: CGPoint(x: 0, y: 1024))
    default:
        canvas.linear([rgb(0x8C7DFF), rgb(0x5B4CF0), rgb(0x251885)], [0, 0.45, 1], from: .zero, to: CGPoint(x: 1024, y: 1024))
        canvas.glow(rgb(0x37C3D6, 0.75), at: CGPoint(x: 900, y: 940), radius: 560)
        canvas.glow(rgb(0xF2A9E0, 0.35), at: CGPoint(x: 120, y: 80), radius: 520)
    }

    // The mark: an "i" built from two widget tiles, in frosted glass.
    let tile = CGPath(roundedRect: CGRect(x: 420, y: 426, width: 184, height: 400), cornerWidth: 58, cornerHeight: 58, transform: nil)
    let dot = CGPath(roundedRect: CGRect(x: 420, y: 198, width: 184, height: 184), cornerWidth: 54, cornerHeight: 54, transform: nil)
    let glass = style == "tinted" ? [rgb(0xFFFFFF), rgb(0xC8C8C8)] : [rgb(0xFFFFFF, 0.96), rgb(0xF1EEFF, 0.78)]
    for (shape, top, bottom) in [(tile, CGFloat(426), CGFloat(826)), (dot, CGFloat(198), CGFloat(382))] {
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -22), blur: 48, color: rgb(0x0B0630, style == "tinted" ? 0 : 0.35))
        canvas.fill(shape, rgb(0xFFFFFF, 0.9))
        c.restoreGState()
        canvas.linear(glass, from: CGPoint(x: 0, y: top), to: CGPoint(x: 0, y: bottom), clip: shape)
        // A bright rim along the top edge, the way light catches glass.
        c.saveGState()
        c.addPath(shape)
        c.clip()
        c.addPath(shape)
        c.setLineWidth(10)
        c.replacePathWithStrokedPath()
        c.clip()
        canvas.linear([rgb(0xFFFFFF, 1), rgb(0xFFFFFF, 0)], from: CGPoint(x: 0, y: top), to: CGPoint(x: 0, y: top + (bottom - top) * 0.5))
        c.restoreGState()
    }
    return canvas
}

try FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)
for (style, name) in [("light", "AppIcon.png"), ("dark", "AppIcon-Dark.png"), ("tinted", "AppIcon-Tinted.png")] {
    drawIcon(style).save(iconDir.appending(path: name), type: .png)
}

// MARK: Sample photos

try FileManager.default.createDirectory(at: sampleDir, withIntermediateDirectories: true)

do { // Golden ridge at dusk
    let p = Canvas(1600, 1200)
    p.linear([rgb(0x24305C), rgb(0x7A5A8C), rgb(0xF0A35E), rgb(0xFFD9A0)], [0, 0.35, 0.68, 0.82], from: .zero, to: CGPoint(x: 0, y: 900))
    p.glow(rgb(0xFFF1CC, 0.95), at: CGPoint(x: 1080, y: 660), radius: 90)
    p.glow(rgb(0xFFC27A, 0.55), at: CGPoint(x: 1080, y: 660), radius: 520)
    let layers: [(CGFloat, CGFloat, UInt32, UInt32)] = [(640, 160, 0xD08A72, 0xC27A69), (720, 200, 0xA05D63, 0x8C4D5A), (820, 260, 0x5E3550, 0x4A2943), (960, 300, 0x2A1730, 0x1B0F20)]
    for (i, layer) in layers.enumerated() {
        let path = ridge(width: 1600, bottom: 1200, base: layer.0, roughness: layer.1, seed: UInt64(11 + i * 7))
        p.linear([rgb(layer.2), rgb(layer.3)], from: CGPoint(x: 0, y: layer.0 - layer.1), to: CGPoint(x: 0, y: 1200), clip: path)
        p.linear([rgb(0xFFD9A0, 0.22), rgb(0xFFD9A0, 0)], from: CGPoint(x: 0, y: layer.0 - 40), to: CGPoint(x: 0, y: layer.0 + 160))
    }
    p.grain(5, seed: 1)
    p.save(sampleDir.appending(path: "sample-ridge.jpg"), type: .jpeg)
}

do { // Tide line
    let p = Canvas(1600, 1200)
    p.linear([rgb(0x8EC0E4), rgb(0xCFE0EE), rgb(0xF8E2CF)], [0, 0.6, 1], from: .zero, to: CGPoint(x: 0, y: 640))
    for (x, y, r) in [(300.0, 200.0, 260.0), (620, 150, 200), (1250, 260, 300), (1450, 160, 180)] as [(CGFloat, CGFloat, CGFloat)] {
        p.glow(rgb(0xFFFFFF, 0.5), at: CGPoint(x: x, y: y), radius: r)
    }
    p.glow(rgb(0xFFF6E3, 1), at: CGPoint(x: 800, y: 610), radius: 60)
    p.glow(rgb(0xFFE2B8, 0.6), at: CGPoint(x: 800, y: 620), radius: 420)
    p.linear([rgb(0x6FA3C2), rgb(0x2F6E92), rgb(0x0E3A57)], [0, 0.4, 1], from: CGPoint(x: 0, y: 640), to: CGPoint(x: 0, y: 1200), clip: CGPath(rect: CGRect(x: 0, y: 640, width: 1600, height: 560), transform: nil))
    var random = Random(state: 7)
    for _ in 0..<120 { // sun glitter and wave lines
        let y = 650 + random.next() * random.next() * 540
        let spread = 40 + (y - 640) * 0.9
        let x = 800 + (random.next() - 0.5) * spread
        let length = 20 + random.next() * 90
        p.fill(CGPath(roundedRect: CGRect(x: x - length / 2, y: y, width: length, height: 3 + random.next() * 3), cornerWidth: 2, cornerHeight: 2, transform: nil), rgb(0xFFF1D6, 0.25 + random.next() * 0.5))
    }
    p.linear([rgb(0xD9C2A3, 0), rgb(0xC9AE8C, 0.9)], from: CGPoint(x: 0, y: 1040), to: CGPoint(x: 0, y: 1200), clip: ridge(width: 1600, bottom: 1200, base: 1090, roughness: 40, seed: 5))
    p.grain(4, seed: 2)
    p.save(sampleDir.appending(path: "sample-tide.jpg"), type: .jpeg)
}

do { // Dunes in late light
    let p = Canvas(1600, 1200)
    p.linear([rgb(0xF4D3B0), rgb(0xF0B98A), rgb(0xE59A62)], [0, 0.6, 1], from: .zero, to: CGPoint(x: 0, y: 700))
    p.glow(rgb(0xFFF4E2, 0.9), at: CGPoint(x: 360, y: 300), radius: 260)
    let dunes: [(CGFloat, CGFloat, UInt32, UInt32)] = [(560, 0.0, 0xE7A86A, 0xC97E45), (700, 0.35, 0xDE9656, 0xA9622F), (860, 0.7, 0xD08446, 0x8C4A22), (1010, 0.2, 0xC27438, 0x6E3517)]
    for (top, phase, light, dark) in dunes {
        let crest = 1600 * (0.25 + phase * 0.6)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: top + 120))
        path.addQuadCurve(to: CGPoint(x: crest, y: top), control: CGPoint(x: crest * 0.55, y: top - 40))
        path.addQuadCurve(to: CGPoint(x: 1600, y: top + 160), control: CGPoint(x: crest + (1600 - crest) * 0.4, y: top + 10))
        path.addLine(to: CGPoint(x: 1600, y: 1200))
        path.addLine(to: CGPoint(x: 0, y: 1200))
        path.closeSubpath()
        p.linear([rgb(light), rgb(dark)], from: CGPoint(x: crest - 200, y: top), to: CGPoint(x: crest + 260, y: top + 200), clip: path)
    }
    p.grain(5, seed: 3)
    p.save(sampleDir.appending(path: "sample-dune.jpg"), type: .jpeg)
}

do { // Night bloom: soft city lights out of focus
    let p = Canvas(1600, 1200)
    p.linear([rgb(0x0B0C1E), rgb(0x1E1033), rgb(0x2A0F2E)], [0, 0.6, 1], from: .zero, to: CGPoint(x: 1600, y: 1200))
    var random = Random(state: 99)
    let palette: [UInt32] = [0xFFB347, 0xFF6B9A, 0x4FD1C5, 0xFFE3A3, 0x9D8CFF]
    for _ in 0..<70 {
        let center = CGPoint(x: random.next() * 1600, y: 200 + random.next() * 900)
        let radius = 30 + random.next() * random.next() * 170
        let color = palette[Int(random.next() * CGFloat(palette.count)) % palette.count]
        p.glow(rgb(color, 0.18 + random.next() * 0.45), at: center, radius: radius)
    }
    p.grain(6, seed: 4)
    p.save(sampleDir.appending(path: "sample-bloom.jpg"), type: .jpeg)
}
