import SwiftUI
import WidgetKit

/// A design's foreground. The widget wraps it in `containerBackground`; in-app previews draw
/// `DesignBackground` behind it. Both use this one view, which is what keeps previews accurate.
struct DesignView: View {
    let design: WidgetDesign
    let size: DesignSize
    var date: Date = .now
    var photo: PhotoState = .none

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if size.isLockScreen {
            AccessoryFace(design: design, size: size, date: date)
        } else {
            let color = design.textColor(dark: scheme == .dark)
            let shadow = design.style.showsShadow
            face
                .foregroundStyle(color)
                .shadow(color: .black.opacity(shadow ? 0.4 : 0), radius: shadow ? 3 : 0, y: shadow ? 1 : 0)
                .overlay {
                    if design.style.showsFrame {
                        ContainerRelativeShape().inset(by: 6).strokeBorder(color.opacity(0.35), lineWidth: 1)
                    }
                }
        }
    }

    @ViewBuilder private var face: some View {
        let type = TypeScale(style: design.style, size: size)
        switch design.kind {
        case .clock: ClockFace(content: design.clock, style: design.style, type: type, tint: design.textColor(dark: scheme == .dark), date: date)
        case .photo: PhotoFace(content: design.photo, style: design.style, type: type, photo: photo)
        case .text: TextFace(content: design.text, style: design.style, type: type)
        case .countdown: CountdownFace(content: design.countdown, style: design.style, type: type, date: date)
        }
    }
}

/// What sits behind a design. In widgets this is the removable container background.
struct DesignBackground: View {
    let design: WidgetDesign
    var photo: PhotoState = .none

    var body: some View {
        if design.kind == .photo {
            Color.black
        } else if design.style.background.fill == .photo {
            ZStack {
                PhotoLayer(content: design.photo, photo: photo, labeled: false)
                Color.black.opacity(design.photo.shade)
            }
        } else {
            BackgroundFill(style: design.style.background, sheen: design.style.showsSheen)
        }
    }

}

struct BackgroundFill: View {
    let style: BackgroundStyle
    var sheen = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            switch style.fill {
            case .automatic:
                BackgroundStyle.automaticColor(dark: scheme == .dark).color
            case .solid:
                style.color(0).color
            case .gradient:
                let (start, end) = Self.points(angle: style.angle)
                LinearGradient(colors: [style.color(0).color, style.color(1).color], startPoint: start, endPoint: end)
            case .aurora:
                style.color(0).color
                EllipticalGradient(colors: [style.color(1).color, style.color(1).color.opacity(0)], center: UnitPoint(x: 0.1, y: 0.05), startRadiusFraction: 0, endRadiusFraction: 0.95)
                EllipticalGradient(colors: [style.color(2).color, style.color(2).color.opacity(0)], center: UnitPoint(x: 0.95, y: 1), startRadiusFraction: 0, endRadiusFraction: 0.85)
            case .photo:
                // DesignBackground draws the actual photo; this is only a neutral stand-in.
                Color(white: 0.25)
            }
            if sheen {
                LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                ContainerRelativeShape()
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)], startPoint: .top, endPoint: .center), lineWidth: 1.5)
            }
        }
    }

    /// 0° runs left to right, 90° top to bottom.
    static func points(angle: Double) -> (UnitPoint, UnitPoint) {
        let radians = angle * .pi / 180
        let dx = cos(radians) / 2, dy = sin(radians) / 2
        return (UnitPoint(x: 0.5 - dx, y: 0.5 - dy), UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}

/// A design at real widget size with the widget's corner shape: the basis of every in-app preview.
/// Lock Screen sizes sit on a stand-in wallpaper because iOS draws them as tinted white.
struct WidgetCanvas: View {
    let design: WidgetDesign
    let size: DesignSize
    var photo: PhotoState = .none
    var screen = CGSize(width: 393, height: 852)

    static let lockInset: CGFloat = 14

    static func naturalSize(_ size: DesignSize, screen: CGSize) -> CGSize {
        let widget = WidgetMetrics.size(for: size, screen: screen)
        guard size.isLockScreen else { return widget }
        return CGSize(width: widget.width + lockInset * 2, height: widget.height + lockInset * 2)
    }

    var body: some View {
        let widget = WidgetMetrics.size(for: size, screen: screen)
        let shape = RoundedRectangle(cornerRadius: WidgetMetrics.cornerRadius, style: .continuous)
        if size.isLockScreen {
            DesignView(design: design, size: size)
                .foregroundStyle(.white)
                .frame(width: widget.width, height: widget.height)
                .padding(Self.lockInset)
                .background(LinearGradient(colors: [RGBA(0x1D2445).color, RGBA(0x45305E).color], startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 18, style: .continuous))
                .environment(\.colorScheme, .dark)
        } else {
            DesignView(design: design, size: size, photo: photo)
                .background { DesignBackground(design: design, photo: photo) }
                .frame(width: widget.width, height: widget.height)
                .containerShape(shape)
                .clipShape(shape)
        }
    }
}

/// Type sizes grow with the widget and the design's text size setting.
private struct TypeScale {
    let style: DesignStyle
    let size: DesignSize

    var factor: CGFloat {
        let base: CGFloat = switch size {
        case .large: 1.45
        case .medium: 1.1
        default: 1
        }
        return base * style.textScale
    }

    func font(_ points: CGFloat, weight: WeightChoice? = nil, design: FontChoice? = nil) -> Font {
        (design ?? style.font).font(size: points * factor, weight: (weight ?? style.weight).weight)
    }
}

private extension View {
    func placed(_ style: DesignStyle) -> some View {
        multilineTextAlignment(style.position.textAlignment)
            .padding(style.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.position.alignment)
    }
}

extension ClockContent {
    private var format: Date.FormatStyle { Date.FormatStyle(timeZone: timeZone) }
    // Text(.currentDate, format:) redraws on its own in widgets, so times never go stale.
    var timeFormat: Date.FormatStyle { format.hour().minute() }
    var hourFormat: Date.FormatStyle { format.hour(.defaultDigits(amPM: .omitted)) }
    var minuteFormat: Date.FormatStyle { format.minute(.twoDigits) }
    var weekdayFormat: Date.FormatStyle { format.weekday(.wide) }
    var dayFormat: Date.FormatStyle { format.day() }
    var monthFormat: Date.FormatStyle { format.month(.wide) }
    var dateFormat: Date.FormatStyle { format.weekday(.abbreviated).month(.abbreviated).day() }
    var inlineFormat: Date.FormatStyle { format.weekday(.abbreviated).day().hour().minute() }

    func dayRange(containing date: Date) -> ClosedRange<Date> {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        return start...(calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400))
    }

    /// Which toggles mean something for each layout.
    var offersDateToggle: Bool { layout == .classic || layout == .stacked }
}

private struct ClockFace: View {
    let content: ClockContent
    let style: DesignStyle
    let type: TypeScale
    let tint: Color
    let date: Date

    var body: some View {
        VStack(alignment: style.position.alignment.horizontal, spacing: style.spacing) {
            if !content.label.isEmpty {
                Text(content.label.uppercased()).font(type.font(11, weight: .bold)).tracking(1.2).opacity(0.65)
            }
            switch content.layout {
            case .classic:
                Text(.currentDate, format: content.timeFormat).font(type.font(40)).widgetAccentable()
                if content.showsDate { secondary(content.dateFormat) }
            case .stacked:
                VStack(alignment: style.position.alignment.horizontal, spacing: -8 * type.factor) {
                    Text(.currentDate, format: content.hourFormat).widgetAccentable()
                    Text(.currentDate, format: content.minuteFormat).opacity(0.55)
                }
                .font(type.font(52))
                if content.showsDate { secondary(content.dateFormat) }
            case .editorial:
                Text(.currentDate, format: content.weekdayFormat).font(type.font(16, weight: .regular)).italic().opacity(0.8)
                Text(.currentDate, format: content.dayFormat).font(type.font(58)).widgetAccentable()
                secondary(content.monthFormat)
                secondary(content.timeFormat)
            case .minimal:
                Text(.currentDate, format: content.timeFormat).font(type.font(48)).widgetAccentable()
            case .dayProgress:
                Text(.currentDate, format: content.weekdayFormat).font(type.font(24)).widgetAccentable()
                secondary(content.dateFormat)
                ProgressView(timerInterval: content.dayRange(containing: date), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(tint)
                secondary(content.timeFormat)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .placed(style)
        // Text applies the environment's time zone over the format's, so set it here.
        .environment(\.timeZone, content.timeZone)
    }

    private func secondary(_ format: Date.FormatStyle) -> some View {
        Text(.currentDate, format: format).font(type.font(13, weight: .medium)).opacity(0.75)
    }
}

private struct PhotoFace: View {
    let content: PhotoContent
    let style: DesignStyle
    let type: TypeScale
    let photo: PhotoState

    var body: some View {
        let hasText = !content.caption.isEmpty || content.showsDate
        ZStack {
            PhotoLayer(content: content, photo: photo, labeled: true)
            if hasText && content.shade > 0 {
                shade
            }
            VStack(alignment: style.position.alignment.horizontal, spacing: style.spacing) {
                if !content.caption.isEmpty {
                    Text(content.caption).font(type.font(17)).widgetAccentable()
                }
                if content.showsDate {
                    Text(.currentDate, format: Date.FormatStyle().weekday(.wide).month(.wide).day()).font(type.font(12, weight: .medium)).opacity(0.85)
                }
            }
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .placed(style)
        }
    }

    @ViewBuilder private var shade: some View {
        let dark = Color.black.opacity(content.shade)
        switch style.position {
        case .topLeading, .top, .topTrailing:
            LinearGradient(colors: [dark, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.8))
        case .bottomLeading, .bottom, .bottomTrailing:
            LinearGradient(colors: [.clear, dark], startPoint: UnitPoint(x: 0.5, y: 0.2), endPoint: .bottom)
        default:
            Color.black.opacity(content.shade * 0.6)
        }
    }
}

/// The photo itself, or a placeholder while it loads, before one is chosen, or if its file is gone.
private struct PhotoLayer: View {
    let content: PhotoContent
    let photo: PhotoState
    /// Backgrounds skip the placeholder's words, since the design's own text sits on top.
    let labeled: Bool

    var body: some View {
        switch photo {
        case .ready(let image): CroppedPhoto(image: image, content: content)
        case .loading: Rectangle().fill(.gray.opacity(0.25))
        case .none: PhotoPlaceholder(missing: false, labeled: labeled)
        case .missing: PhotoPlaceholder(missing: true, labeled: labeled)
        }
    }
}

private struct CroppedPhoto: View {
    let image: CGImage
    let content: PhotoContent

    var body: some View {
        GeometryReader { proxy in
            let rect = PhotoCrop.layout(image: CGSize(width: image.width, height: image.height), frame: proxy.size, focus: CGPoint(x: content.focusX, y: content.focusY), zoom: content.zoom)
            Image(decorative: image, scale: 1)
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .photoFilter(content.filter)
        .clipped()
    }
}

private struct PhotoPlaceholder: View {
    let missing: Bool
    let labeled: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.34), Color(white: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if labeled {
                VStack(spacing: 6) {
                    Image(systemName: missing ? "exclamationmark.triangle" : "photo.badge.plus").font(.title2)
                    Text(missing ? "Photo unavailable" : "Choose a photo").font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

private extension View {
    @ViewBuilder func photoFilter(_ filter: PhotoContent.Filter) -> some View {
        switch filter {
        case .none: self
        case .mono: grayscale(1).contrast(1.1)
        case .warm: colorMultiply(Color(red: 1, green: 0.92, blue: 0.8)).saturation(1.1)
        case .cool: colorMultiply(Color(red: 0.85, green: 0.93, blue: 1))
        case .fade: saturation(0.7).contrast(0.85).brightness(0.05)
        }
    }
}

private struct TextFace: View {
    let content: TextContent
    let style: DesignStyle
    let type: TypeScale

    var body: some View {
        VStack(alignment: style.position.alignment.horizontal, spacing: style.spacing) {
            switch content.layout {
            case .plain:
                Text(content.text).font(type.font(20)).widgetAccentable()
            case .quote:
                Image(systemName: "quote.opening").font(type.font(22, weight: .bold)).opacity(0.45)
                Text(content.text).font(type.font(19)).widgetAccentable()
                if !content.detail.isEmpty {
                    Text("— \(content.detail)").font(type.font(12, weight: .medium)).opacity(0.7)
                }
            case .note:
                if !content.detail.isEmpty {
                    Text(content.detail.uppercased()).font(type.font(11, weight: .bold)).tracking(1.2).opacity(0.6)
                }
                Text(content.text).font(type.font(19)).widgetAccentable()
            case .headline:
                Text(content.text).font(type.font(36)).minimumScaleFactor(0.3).widgetAccentable()
            }
        }
        .minimumScaleFactor(0.5)
        .placed(style)
    }
}

private struct CountdownFace: View {
    let content: CountdownContent
    let style: DesignStyle
    let type: TypeScale
    let date: Date

    var body: some View {
        let days = content.days(from: date)
        VStack(alignment: style.position.alignment.horizontal, spacing: style.spacing) {
            switch content.layout {
            case .number:
                Image(systemName: content.symbol).font(type.font(17)).opacity(0.8)
                Text(days == 0 ? "Today" : "\(abs(days))").font(type.font(days == 0 ? 38 : 54)).widgetAccentable()
                Text(content.caption(days: days)).font(type.font(13, weight: .medium)).opacity(0.75)
                timeLeft(days: days)
            case .ring:
                ZStack {
                    Circle().stroke(lineWidth: 7 * type.factor).opacity(0.18)
                    Circle()
                        .trim(from: 0, to: content.progress(at: date))
                        .stroke(style: StrokeStyle(lineWidth: 7 * type.factor, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                    VStack(spacing: 0) {
                        Text(days == 0 ? "Today" : "\(abs(days))").font(type.font(days == 0 ? 17 : 30))
                        if days != 0 {
                            Text(abs(days) == 1 ? "day" : "days").font(type.font(11, weight: .medium)).opacity(0.7)
                        }
                    }
                    .padding(12 * type.factor)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 84 * type.factor, maxHeight: 84 * type.factor)
                Label(content.title, systemImage: content.symbol).font(type.font(13, weight: .medium)).opacity(0.85)
            case .sentence:
                Image(systemName: content.symbol).font(type.font(20)).opacity(0.8)
                Text(content.title).font(type.font(24)).widgetAccentable()
                Text(content.phrase(days: days)).font(type.font(16, weight: .medium)).opacity(0.75)
                timeLeft(days: days)
            }
        }
        .lineLimit(2)
        .minimumScaleFactor(0.5)
        .placed(style)
    }

    @ViewBuilder private func timeLeft(days: Int) -> some View {
        if content.includesTime && days == 0 && content.date > date {
            Text(content.date, style: .relative).font(type.font(13, weight: .medium)).opacity(0.75)
        }
    }
}

/// Lock Screen layouts. iOS tints these to match the wallpaper, so they use type and shape only.
private struct AccessoryFace: View {
    let design: WidgetDesign
    let size: DesignSize
    let date: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            switch size {
            case .circular: circular
            case .rectangular: rectangular.frame(maxWidth: .infinity, alignment: alignment)
            default: inline
            }
        }
        .environment(\.timeZone, design.clock.timeZone)
    }

    private var alignment: Alignment {
        switch design.style.position.textAlignment {
        case .center: .center
        case .trailing: .trailing
        default: .leading
        }
    }

    private var days: Int { design.countdown.days(from: date) }

    private func font(_ points: CGFloat, _ weight: WeightChoice? = nil) -> Font {
        design.style.font.font(size: points * design.style.textScale, weight: (weight ?? design.style.weight).weight)
    }

    @ViewBuilder private var circular: some View {
        switch design.kind {
        case .clock:
            ZStack {
                backdrop
                VStack(spacing: -3) {
                    Text(.currentDate, format: design.clock.hourFormat)
                    Text(.currentDate, format: design.clock.minuteFormat)
                }
                .font(font(21))
                .widgetAccentable()
            }
        case .countdown:
            Gauge(value: design.countdown.progress(at: date)) {
                Image(systemName: design.countdown.symbol)
            } currentValueLabel: {
                Text(days == 0 ? "Now" : "\(abs(days))").font(font(17))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        default:
            ZStack {
                backdrop
                Text(design.text.text)
                    .font(font(12))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .padding(6)
            }
        }
    }

    @ViewBuilder private var rectangular: some View {
        let horizontal = alignment.horizontal
        switch design.kind {
        case .clock:
            VStack(alignment: horizontal, spacing: 0) {
                if !design.clock.label.isEmpty {
                    Text(design.clock.label).font(font(12, .semibold))
                }
                Text(.currentDate, format: design.clock.timeFormat).font(font(30)).widgetAccentable()
                if design.clock.showsDate {
                    Text(.currentDate, format: design.clock.dateFormat).font(font(13, .medium))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        case .countdown:
            VStack(alignment: horizontal, spacing: 2) {
                Label(design.countdown.title, systemImage: design.countdown.symbol).font(font(13, .semibold))
                Text(days == 0 ? "Today" : design.countdown.phrase(days: days)).font(font(21)).widgetAccentable()
                if design.countdown.layout == .ring {
                    ProgressView(value: design.countdown.progress(at: date))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        default:
            VStack(alignment: horizontal, spacing: 1) {
                if !design.text.detail.isEmpty {
                    Text(design.text.detail).font(font(12, .semibold)).lineLimit(1)
                }
                Text(design.text.text).font(font(15)).lineLimit(3).widgetAccentable()
            }
            .multilineTextAlignment(design.style.position.textAlignment)
            .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder private var inline: some View {
        switch design.kind {
        case .clock:
            if design.clock.label.isEmpty {
                Text(.currentDate, format: design.clock.inlineFormat)
            } else {
                Text("\(design.clock.label) \(Text(.currentDate, format: design.clock.timeFormat))")
            }
        case .countdown:
            Label("\(design.countdown.title) \(design.countdown.phrase(days: days))", systemImage: design.countdown.symbol)
        default:
            Text(design.text.text)
        }
    }

    @ViewBuilder private var backdrop: some View {
        if renderingMode == .vibrant {
            AccessoryWidgetBackground()
        } else {
            Circle().fill(.white.opacity(0.16))
        }
    }
}
