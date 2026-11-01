import SwiftUI

/// The widget types Infly can render.
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case clock, photo, text, countdown

    var id: Self { self }

    var title: String {
        switch self {
        case .clock: "Clock"
        case .photo: "Photo"
        case .text: "Text"
        case .countdown: "Countdown"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .photo: "photo"
        case .text: "text.quote"
        case .countdown: "hourglass"
        }
    }

    var blurb: String {
        switch self {
        case .clock: "Time and date in your own type."
        case .photo: "A favorite photo, framed just right."
        case .text: "A note, a quote, a reminder."
        case .countdown: "Days until something good."
        }
    }

    /// The Lock Screen tints everything to one color, so photos stay on the Home Screen.
    var sizes: [DesignSize] { self == .photo ? DesignSize.home : DesignSize.allCases }
}

enum DesignSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large, circular, rectangular, inline

    static let home: [DesignSize] = [.small, .medium, .large]
    static let lock: [DesignSize] = [.circular, .rectangular, .inline]

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var isLockScreen: Bool { Self.lock.contains(self) }
    var placement: String { isLockScreen ? "Lock Screen" : "Home Screen" }
    /// Wide sizes get a full-width card in galleries.
    var isWide: Bool { self == .medium || self == .large }
}

/// An sRGB color that survives JSON round trips (SwiftUI's Color isn't Codable).
struct RGBA: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity) }

    /// WCAG relative luminance.
    var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

extension RGBA {
    init(_ hex: UInt32, opacity: Double = 1) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }

    static let white = RGBA(0xFFFFFF)
    static let ink = RGBA(0x1C1C1E)
}

struct BackgroundStyle: Codable, Hashable {
    enum Fill: String, Codable, CaseIterable, Identifiable {
        /// `photo` draws the design's photo (its PhotoContent) behind any widget type.
        case automatic, solid, gradient, aurora, photo
        var id: Self { self }
        var title: String { self == .automatic ? "Auto" : rawValue.capitalized }
    }

    var fill: Fill = .automatic
    /// Solid uses the first color, gradient the first two, aurora all three.
    var colors: [RGBA] = [RGBA(0x5B4CF0), RGBA(0x2A1F7A), RGBA(0x37C3D6)]
    var angle: Double = 135

    var isAdaptive: Bool { fill == .automatic }

    func color(_ index: Int) -> RGBA {
        colors.indices.contains(index) ? colors[index] : colors.last ?? .ink
    }

    static func automaticColor(dark: Bool) -> RGBA { dark ? .ink : .white }

    func visibleColors(dark: Bool) -> [RGBA] {
        switch fill {
        case .automatic: [Self.automaticColor(dark: dark)]
        case .solid: [color(0)]
        case .gradient: [color(0), color(1)]
        case .aurora: [color(0), color(1), color(2)]
        case .photo: [RGBA(0x2A2A2A)]
        }
    }

    static func solid(_ hex: UInt32) -> Self {
        Self(fill: .solid, colors: [RGBA(hex), RGBA(hex), RGBA(hex)])
    }

    static func gradient(_ a: UInt32, _ b: UInt32, angle: Double = 135) -> Self {
        Self(fill: .gradient, colors: [RGBA(a), RGBA(b), RGBA(b)], angle: angle)
    }

    static func aurora(_ base: UInt32, _ glow: UInt32, _ accent: UInt32) -> Self {
        Self(fill: .aurora, colors: [RGBA(base), RGBA(glow), RGBA(accent)])
    }
}

enum FontChoice: String, Codable, CaseIterable, Identifiable {
    case sans, rounded, serif, mono, narrow, wide

    var id: Self { self }
    var title: String { rawValue.capitalized }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .sans: .system(size: size, weight: weight)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .serif: .system(size: size, weight: weight, design: .serif)
        case .mono: .system(size: size, weight: weight, design: .monospaced)
        case .narrow: .system(size: size, weight: weight).width(.condensed)
        case .wide: .system(size: size, weight: weight).width(.expanded)
        }
    }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case thin, light, regular, medium, semibold, bold, heavy, black

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var weight: Font.Weight {
        switch self {
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

enum ContentPosition: String, Codable, CaseIterable, Identifiable {
    case topLeading, top, topTrailing, leading, center, trailing, bottomLeading, bottom, bottomTrailing

    var id: Self { self }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .topLeading, .leading, .bottomLeading: .leading
        case .topTrailing, .trailing, .bottomTrailing: .trailing
        default: .center
        }
    }

    var isTop: Bool { [.topLeading, .top, .topTrailing].contains(self) }

    var title: String {
        switch self {
        case .topLeading: "Top left"
        case .top: "Top"
        case .topTrailing: "Top right"
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        case .bottomLeading: "Bottom left"
        case .bottom: "Bottom"
        case .bottomTrailing: "Bottom right"
        }
    }
}

struct DesignStyle: Codable, Hashable {
    var font: FontChoice = .sans
    var weight: WeightChoice = .semibold
    var textScale: Double = 1
    /// nil picks white or near-black, whichever reads better on the background.
    var textColor: RGBA?
    var position: ContentPosition = .center
    var padding: Double = 16
    var spacing: Double = 4
    var background = BackgroundStyle()
    var showsFrame = false
    var showsSheen = false
    var showsShadow = false
}

struct ClockContent: Codable, Hashable {
    enum Layout: String, Codable, CaseIterable, Identifiable {
        case classic, stacked, editorial, minimal, dayProgress
        var id: Self { self }
        var title: String { self == .dayProgress ? "Day" : rawValue.capitalized }
    }

    var layout: Layout = .classic
    var showsDate = true
    /// nil follows the iPhone's time zone.
    var timeZoneID: String?
    var label = ""

    var timeZone: TimeZone { timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .autoupdatingCurrent }
}

struct PhotoContent: Codable, Hashable {
    enum Filter: String, Codable, CaseIterable, Identifiable {
        case none, mono, warm, cool, fade
        var id: Self { self }
        var title: String { self == .none ? "Original" : rawValue.capitalized }
    }

    /// A file in the shared Images folder, or a bundled sample named "sample-…".
    var imageName: String?
    /// Which part of the photo shows when it overflows the widget, 0…1 on each axis.
    var focusX = 0.5
    var focusY = 0.5
    var zoom = 1.0
    var caption = ""
    var showsDate = false
    var filter: Filter = .none
    /// Darkens the caption's edge so text stays readable.
    var shade = 0.3
}

struct TextContent: Codable, Hashable {
    enum Layout: String, Codable, CaseIterable, Identifiable {
        case plain, quote, note, headline
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    var layout: Layout = .plain
    var text = "Make it yours."
    var detail = ""
}

struct CountdownContent: Codable, Hashable {
    enum Layout: String, Codable, CaseIterable, Identifiable {
        case number, ring, sentence
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    var layout: Layout = .number
    var title = "Big Day"
    var date = Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: .now)) ?? .now
    var includesTime = false
    /// Where the ring layout starts filling from.
    var start = Calendar.current.startOfDay(for: .now)
    var symbol = "sparkles"

    /// Whole calendar days until the event; negative once it has passed.
    func days(from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    func progress(at now: Date) -> Double {
        let total = date.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(start) / total, 0), 1)
    }

    /// "in 12 days", "is today", "was 3 days ago".
    func phrase(days: Int) -> String {
        switch days {
        case 0: "is today"
        case 1: "is tomorrow"
        case -1: "was yesterday"
        case 2...: "in \(days) days"
        default: "was \(-days) days ago"
        }
    }

    /// The line under a big day count.
    func caption(days: Int) -> String {
        switch days {
        case 0: title
        case 1...: "\(days == 1 ? "day" : "days") until \(title)"
        default: "\(days == -1 ? "day" : "days") since \(title)"
        }
    }

    static let symbols = ["sparkles", "gift", "birthday.cake", "airplane", "suitcase", "heart", "star", "flag.checkered", "graduationcap", "house", "music.note", "sun.max", "snowflake", "party.popper"]
}

struct WidgetDesign: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var kind: WidgetKind
    var size: DesignSize
    /// The preset this design started from; "Reset to Preset" restores its look.
    var presetID: String
    var style = DesignStyle()
    var clock = ClockContent()
    var photo = PhotoContent()
    var text = TextContent()
    var countdown = CountdownContent()
    var created = Date.now
    var updated = Date.now

    var summary: String { "\(size.title) · \(kind.title)" }

    /// Photo widgets, and any widget with a photo background.
    var usesPhoto: Bool { kind == .photo || (style.background.fill == .photo && !size.isLockScreen) }

    func textRGBA(dark: Bool) -> RGBA {
        style.textColor ?? (usesPhoto ? .white : style.background.legibleText(dark: dark))
    }

    func textColor(dark: Bool) -> Color { textRGBA(dark: dark).color }
}

extension WidgetDesign {
    private static let codePrefix = "INFLY1:"

    /// A pasteable copy of the design. Sideloading with a free Apple ID usually can't grant an
    /// App Group, so a widget can show a design from a code pasted into its own settings instead.
    var widgetCode: String {
        guard let json = try? JSONEncoder().encode(self), let packed = try? (json as NSData).compressed(using: .zlib) else { return "" }
        return Self.codePrefix + (packed as Data).base64EncodedString()
    }

    init?(widgetCode: String) {
        let code = widgetCode.trimmingCharacters(in: .whitespacesAndNewlines)
        // Real codes are about 1,000 characters; the cap keeps a bad paste from ballooning in the widget.
        guard code.count < 8_000, code.hasPrefix(Self.codePrefix),
              let packed = Data(base64Encoded: String(code.dropFirst(Self.codePrefix.count))),
              let json = try? (packed as NSData).decompressed(using: .zlib) as Data,
              let design = try? JSONDecoder().decode(WidgetDesign.self, from: json) else { return nil }
        self = design
    }
}

extension BackgroundStyle {
    /// White or near-black, whichever reads better. Text can land anywhere on a gradient,
    /// so this compares worst-case WCAG contrast over every visible color.
    func legibleText(dark: Bool) -> RGBA {
        func worstContrast(_ text: RGBA) -> Double {
            visibleColors(dark: dark).map { color in
                (max(text.luminance, color.luminance) + 0.05) / (min(text.luminance, color.luminance) + 0.05)
            }.min() ?? 1
        }
        return worstContrast(.white) >= worstContrast(.ink) ? .white : .ink
    }
}
