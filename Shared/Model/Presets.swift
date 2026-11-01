import Foundation

enum PresetCategory: String, CaseIterable, Identifiable {
    case minimal, glass, photography, productivity, color
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct Preset: Identifiable {
    let id: String
    let name: String
    let category: PresetCategory
    let blurb: String
    let template: WidgetDesign

    func makeDesign() -> WidgetDesign {
        var design = template
        design.id = UUID()
        design.created = .now
        design.updated = .now
        return design
    }
}

struct PresetCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let presetIDs: [String]
    let tint: BackgroundStyle

    var presets: [Preset] { presetIDs.compactMap(Presets.preset(id:)) }
}

/// A background and text color pairing, offered as one-tap styles in the editor.
struct Palette: Identifiable {
    let id: String
    let name: String
    let background: BackgroundStyle
    var text: RGBA?

    static let system = Palette(id: "system", name: "System", background: BackgroundStyle())
    static let paper = Palette(id: "paper", name: "Paper", background: .solid(0xF3EEE4), text: RGBA(0x2B2723))
    static let ink = Palette(id: "ink", name: "Ink", background: .solid(0x141518), text: RGBA(0xF2EDE4))
    static let frost = Palette(id: "frost", name: "Frost", background: .gradient(0xE6ECFF, 0xB7C2F2, angle: 120), text: RGBA(0x1F2552))
    static let mist = Palette(id: "mist", name: "Mist", background: .aurora(0xEEE9FF, 0xC6E3F7, 0xF7D7E8), text: RGBA(0x2B2D42))
    static let iris = Palette(id: "iris", name: "Iris", background: .aurora(0x221A66, 0x6A5CFF, 0x37C3D6))
    static let night = Palette(id: "night", name: "Midnight", background: .gradient(0x0E1430, 0x26346A, angle: 160), text: RGBA(0xE1E7FF))
    static let plum = Palette(id: "plum", name: "Plum", background: .aurora(0x1B0E29, 0x6B2D6E, 0xD2668A), text: RGBA(0xF8E9F0))
    static let ember = Palette(id: "ember", name: "Ember", background: .gradient(0xFF8A4C, 0xD7263D), text: RGBA(0xFFF4EC))
    static let lagoon = Palette(id: "lagoon", name: "Lagoon", background: .gradient(0x22B8A8, 0x0B5370, angle: 150))
    static let sage = Palette(id: "sage", name: "Sage", background: .solid(0xC8D5BD), text: RGBA(0x243427))
    static let citrus = Palette(id: "citrus", name: "Citrus", background: .solid(0xFFD84D), text: RGBA(0x1E1B0F))

    static let all: [Palette] = [.system, .paper, .ink, .frost, .mist, .iris, .night, .plum, .ember, .lagoon, .sage, .citrus]
}

extension WidgetDesign {
    mutating func apply(_ palette: Palette) {
        style.background = palette.background
        style.textColor = palette.text
    }
}

enum Presets {
    static func preset(id: String) -> Preset? { (all + blanks).first { $0.id == id } }

    static func blank(_ kind: WidgetKind) -> Preset { blanks.first { $0.template.kind == kind } ?? blanks[0] }

    /// Offered during onboarding: one per widget type.
    static let starterIDs = ["frost", "golden-ridge", "clear-day", "prism"]

    static let collections: [PresetCollection] = [
        PresetCollection(id: "soft-glass", title: "Soft Glass", subtitle: "Pale layers, fine edges, gentle light.", presetIDs: ["frost", "morning-mist", "prism", "clear-day"], tint: .aurora(0xDCE4FF, 0xB9C6F7, 0xF2D7EC)),
        PresetCollection(id: "golden-hour", title: "Golden Hour", subtitle: "Your photos, framed with care.", presetIDs: ["golden-ridge", "ridge-clock", "tide-line", "dune-light", "night-bloom"], tint: .gradient(0xF6B36A, 0xB8476B)),
        PresetCollection(id: "paper-ink", title: "Paper & Ink", subtitle: "Quiet type for calm screens.", presetIDs: ["hairline", "margin-note", "quiet-hours", "plum-night"], tint: .gradient(0xF3EEE4, 0xD5CBBA)),
        PresetCollection(id: "count-the-days", title: "Count the Days", subtitle: "Trips, launches and everything worth the wait.", presetIDs: ["launch-day", "prism", "lagoon", "next-up"], tint: .gradient(0x22B8A8, 0x0B5370)),
    ]

    static let all: [Preset] = [
        make("hairline", "Hairline", .minimal, .clock, .small, "A light, airy clock that follows Light and Dark Mode.") {
            $0.style.weight = .light
            $0.style.showsFrame = true
        },
        make("quiet-hours", "Quiet Hours", .minimal, .clock, .medium, "Just the time, in fine monospaced digits.") {
            $0.clock.layout = .minimal
            $0.style.font = .mono
            $0.style.weight = .thin
            $0.style.textScale = 1.25
            $0.apply(.ink)
        },
        make("margin-note", "Margin Note", .minimal, .text, .medium, "A quiet note on warm paper.") {
            $0.text = TextContent(layout: .note, text: "Write less. Notice more.", detail: "Today")
            $0.style.font = .serif
            $0.style.weight = .regular
            $0.style.position = .leading
            $0.style.padding = 20
            $0.apply(.paper)
        },
        make("pocket-clock", "Pocket Clock", .minimal, .clock, .circular, "Hour over minute, made for the Lock Screen.") {
            $0.clock.layout = .stacked
            $0.style.font = .rounded
        },
        make("inline-date", "Inline Date", .minimal, .clock, .inline, "The date and time in one line above your clock.") {
            $0.clock.layout = .classic
        },
        make("frost", "Frost", .glass, .clock, .small, "Cool, pale layers with a soft light edge.") {
            $0.clock.layout = .stacked
            $0.style.font = .rounded
            $0.style.weight = .medium
            $0.style.showsSheen = true
            $0.style.showsFrame = true
            $0.apply(.frost)
        },
        make("morning-mist", "Morning Mist", .glass, .clock, .medium, "A serif date that greets the morning.") {
            $0.clock.layout = .editorial
            $0.style.font = .serif
            $0.style.weight = .regular
            $0.style.position = .leading
            $0.style.padding = 20
            $0.style.showsSheen = true
            $0.style.showsFrame = true
            $0.apply(.mist)
        },
        make("prism", "Prism", .glass, .countdown, .small, "A glowing ring that fills as the day gets close.") {
            $0.countdown = CountdownContent(layout: .ring, title: "Lisbon", date: days(18), start: days(-12), symbol: "airplane")
            $0.style.font = .rounded
            $0.style.showsSheen = true
            $0.apply(.iris)
        },
        make("clear-day", "Clear Day", .glass, .text, .medium, "Your words, set like a page from a good book.") {
            $0.text = TextContent(layout: .quote, text: "Slow mornings are part of the plan.", detail: "Note to self")
            $0.style.font = .serif
            $0.style.weight = .medium
            $0.style.position = .leading
            $0.style.padding = 20
            $0.style.showsSheen = true
            $0.style.showsFrame = true
            $0.apply(.frost)
        },
        make("golden-ridge", "Golden Ridge", .photography, .photo, .small, "Warm light with room for a caption.") {
            $0.photo = PhotoContent(imageName: "sample-ridge", caption: "Somewhere quiet", shade: 0.45)
            $0.style.font = .serif
            $0.style.weight = .medium
            $0.style.position = .bottomLeading
            $0.style.padding = 14
            $0.style.showsFrame = true
        },
        make("tide-line", "Tide Line", .photography, .photo, .medium, "A wide horizon and today's date.") {
            $0.photo = PhotoContent(imageName: "sample-tide", focusY: 0.55, caption: "Low tide, high hopes", showsDate: true, shade: 0.4)
            $0.style.position = .bottomLeading
        },
        make("dune-light", "Dune Light", .photography, .photo, .large, "Big, bold type over soft dunes.") {
            $0.photo = PhotoContent(imageName: "sample-dune", focusY: 0.6, caption: "Saturday light", showsDate: true, shade: 0.35)
            $0.style.font = .wide
            $0.style.weight = .bold
            $0.style.position = .topLeading
            $0.style.padding = 20
        },
        make("ridge-clock", "Ridge Clock", .photography, .clock, .small, "Big numerals over a quiet ridge.") {
            $0.clock.layout = .stacked
            $0.style.font = .rounded
            $0.style.showsShadow = true
            $0.style.background.fill = .photo
            $0.photo = PhotoContent(imageName: "sample-ridge", focusY: 0.75, shade: 0.15)
        },
        make("night-bloom", "Night Bloom", .photography, .photo, .small, "Soft lights and the date, nothing else.") {
            $0.photo = PhotoContent(imageName: "sample-bloom", showsDate: true, shade: 0.35)
            $0.style.font = .rounded
            $0.style.position = .bottom
        },
        make("day-meter", "Day Meter", .productivity, .clock, .medium, "See how much of today is left at a glance.") {
            $0.clock.layout = .dayProgress
            $0.style.position = .leading
            $0.style.padding = 20
            $0.apply(.night)
        },
        make("two-cities", "Two Cities", .productivity, .clock, .small, "Keep someone else's time zone close.") {
            $0.clock = ClockContent(layout: .classic, showsDate: true, timeZoneID: "Asia/Tokyo", label: "Tokyo")
            $0.style.font = .narrow
            $0.style.weight = .bold
            $0.style.position = .leading
            $0.apply(.ink)
        },
        make("launch-day", "Launch Day", .productivity, .countdown, .medium, "A bold day count for your next deadline.") {
            $0.countdown = CountdownContent(layout: .number, title: "Launch", date: days(9), symbol: "flag.checkered")
            $0.style.font = .narrow
            $0.style.weight = .heavy
            $0.style.position = .leading
            $0.style.padding = 20
            $0.apply(.paper)
        },
        make("focus-card", "Focus Card", .productivity, .text, .small, "One thing that matters today.") {
            $0.text = TextContent(layout: .note, text: "Finish the first draft", detail: "Focus")
            $0.style.position = .topLeading
            $0.apply(.sage)
        },
        make("next-up", "Next Up", .productivity, .countdown, .rectangular, "Your next trip, counted down on the Lock Screen.") {
            $0.countdown = CountdownContent(layout: .number, title: "Trip", date: days(5), symbol: "suitcase")
            $0.style.font = .rounded
            $0.style.position = .leading
        },
        make("ember", "Ember", .color, .clock, .small, "Big, warm numerals in a sunset gradient.") {
            $0.clock.layout = .stacked
            $0.clock.showsDate = false
            $0.style.font = .rounded
            $0.style.weight = .heavy
            $0.apply(.ember)
        },
        make("lagoon", "Lagoon", .color, .countdown, .medium, "A calm, cool countdown to time off.") {
            $0.countdown = CountdownContent(layout: .sentence, title: "Summer break", date: days(40), symbol: "sun.max")
            $0.style.font = .rounded
            $0.style.weight = .bold
            $0.style.position = .leading
            $0.style.padding = 20
            $0.apply(.lagoon)
        },
        make("citrus", "Citrus", .color, .text, .small, "A bright nudge in heavy type.") {
            $0.text = TextContent(layout: .headline, text: "Go outside.")
            $0.style.font = .wide
            $0.style.weight = .black
            $0.style.position = .bottomLeading
            $0.apply(.citrus)
        },
        make("plum-night", "Plum Night", .color, .clock, .large, "An editorial date in deep plum.") {
            $0.clock.layout = .editorial
            $0.style.font = .serif
            $0.style.weight = .light
            $0.style.position = .bottomLeading
            $0.style.padding = 24
            $0.apply(.plum)
        },
    ]

    /// Starting points for "New Widget", one per type; not shown in Discover.
    static let blanks: [Preset] = [
        make("blank-clock", "Clock", .minimal, .clock, .small, "") { _ in },
        make("blank-photo", "Photo", .photography, .photo, .small, "") {
            $0.style.position = .bottomLeading
            $0.style.padding = 14
        },
        make("blank-text", "Text", .minimal, .text, .small, "") { _ in },
        make("blank-countdown", "Countdown", .minimal, .countdown, .small, "") { _ in },
    ]

    private static func make(_ id: String, _ name: String, _ category: PresetCategory, _ kind: WidgetKind, _ size: DesignSize, _ blurb: String, _ configure: (inout WidgetDesign) -> Void) -> Preset {
        var design = WidgetDesign(name: name, kind: kind, size: size, presetID: id)
        configure(&design)
        return Preset(id: id, name: name, category: category, blurb: blurb, template: design)
    }

    private static func days(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }
}
