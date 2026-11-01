import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoState {
    /// No photo chosen yet.
    case none
    case loading
    case ready(CGImage)
    /// A photo was chosen but its file is gone.
    case missing
}

enum PhotoError: Error {
    case unreadable, unwritable
}

/// Photo storage and decoding. ImageIO decodes straight to the needed size, which keeps
/// the widget extension well inside its memory limit.
enum PhotoFiles {
    static let maxStoredPixels = 2048

    /// Downsizes a picked photo, applies its orientation, and saves it as JPEG. Returns the file name.
    static func store(_ data: Data, in folder: URL) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = thumbnail(from: source, maxPixels: maxStoredPixels) else { throw PhotoError.unreadable }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        let url = folder.appending(path: name)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw PhotoError.unwritable }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PhotoError.unwritable }
        return name
    }

    /// Bundled samples ship inside both the app and the widget extension.
    static func url(for name: String, root: URL) -> URL? {
        if name.hasPrefix("sample-") { return Bundle.main.url(forResource: name, withExtension: "jpg") }
        let url = root.appending(path: "Images").appending(path: name)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    static func load(_ name: String?, root: URL, maxPixels: Int) -> PhotoState {
        guard let name else { return .none }
        guard let url = url(for: name, root: root),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = thumbnail(from: source, maxPixels: maxPixels) else { return .missing }
        return .ready(image)
    }

    private static func thumbnail(from source: CGImageSource, maxPixels: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// Where to draw a photo so it fills a frame, zoomed, with `focus` choosing which part shows.
enum PhotoCrop {
    static func layout(image: CGSize, frame: CGSize, focus: CGPoint, zoom: Double) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: frame) }
        let scale = max(frame.width / image.width, frame.height / image.height) * max(zoom, 1)
        let drawn = CGSize(width: image.width * scale, height: image.height * scale)
        let overflow = CGSize(width: drawn.width - frame.width, height: drawn.height - frame.height)
        return CGRect(x: -overflow.width * clamp(focus.x), y: -overflow.height * clamp(focus.y), width: drawn.width, height: drawn.height)
    }

    /// How far the photo extends past the frame on each axis, for turning drags into focus changes.
    static func overflow(image: CGSize, frame: CGSize, zoom: Double) -> CGSize {
        let drawn = layout(image: image, frame: frame, focus: .zero, zoom: zoom).size
        return CGSize(width: drawn.width - frame.width, height: drawn.height - frame.height)
    }

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
