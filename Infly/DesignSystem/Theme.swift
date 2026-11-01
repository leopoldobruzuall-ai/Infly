import SwiftUI
import UIKit

enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 24
    static let panel: CGFloat = 30
}

/// UserDefaults keys for app preferences.
enum Prefs {
    static let appearance = "appearance"
    static let haptics = "haptics"
    static let solidPanels = "solidPanels"
    static let reduceMotion = "reduceMotion"
    static let hasOnboarded = "hasOnboarded"
    static let hasSavedWidget = "hasSavedWidget"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// System Reduce Motion, or Infly's own switch for it.
struct MotionPreference: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var system
    @AppStorage(Prefs.reduceMotion) private var app = false

    var reduced: Bool { system || app }

    func animation(_ animation: Animation = .smooth) -> Animation? { reduced ? nil : animation }
}

enum Screen {
    /// Portrait screen size, used to draw previews at the same size as real widgets.
    @MainActor static var size: CGSize {
        let bounds = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds }.first
            ?? CGRect(x: 0, y: 0, width: 393, height: 852)
        return CGSize(width: min(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
    }
}

/// The soft wash behind every screen. It gives glass something to refract without competing with content.
struct AppBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            EllipticalGradient(colors: [Color.accentColor.opacity(scheme == .dark ? 0.26 : 0.13), .clear], center: .topLeading, startRadiusFraction: 0, endRadiusFraction: 0.85)
            EllipticalGradient(colors: [Color.teal.opacity(scheme == .dark ? 0.14 : 0.09), .clear], center: .bottomTrailing, startRadiusFraction: 0, endRadiusFraction: 0.75)
        }
        .ignoresSafeArea()
    }
}

/// Content cards: frosted material, a hairline edge and a soft shadow. Opaque when transparency is reduced.
private struct CardSurface: ViewModifier {
    let radius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage(Prefs.solidPanels) private var solidPanels = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let increased = contrast == .increased
        content
            .background {
                if reduceTransparency || solidPanels {
                    shape.fill(Color(.secondarySystemGroupedBackground))
                } else {
                    shape.fill(.thinMaterial)
                }
            }
            .overlay {
                shape.strokeBorder(
                    increased ? AnyShapeStyle(Color.primary.opacity(0.35)) : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)),
                    lineWidth: increased ? 1.5 : 0.75
                )
            }
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }
}

/// Floating controls: Liquid Glass on iOS 26, a material fallback before that.
private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(Prefs.solidPanels) private var solidPanels = false

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency || solidPanels {
            content
                .background(Color(.secondarySystemBackground), in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.15), lineWidth: 1))
        } else {
            // The iOS 26 SDK ships with Swift 6.2; older Xcodes build the material version.
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            } else {
                material(content)
            }
            #else
            material(content)
            #endif
        }
    }

    private func material(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.3), lineWidth: 0.75))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

private struct Haptic<T: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: T

    @AppStorage(Prefs.haptics) private var enabled = true

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}

extension View {
    func cardSurface(radius: CGFloat = Radius.card) -> some View {
        modifier(CardSurface(radius: radius))
    }

    func glassSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive))
    }

    func haptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        modifier(Haptic(feedback: feedback, trigger: trigger))
    }

    /// The main call to action: Liquid Glass on iOS 26, a filled capsule before.
    @ViewBuilder func prominentStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { buttonStyle(.glassProminent) } else { buttonStyle(.borderedProminent) }
        #else
        buttonStyle(.borderedProminent)
        #endif
    }

    @ViewBuilder func secondaryStyle() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { buttonStyle(.glass) } else { buttonStyle(.bordered) }
        #else
        buttonStyle(.bordered)
        #endif
    }

    @ViewBuilder func minimizingTabBar() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { tabBarMinimizeBehavior(.onScrollDown) } else { self }
        #else
        self
        #endif
    }

    /// Cards zoom into the editor and back. Skipped when motion is reduced (no namespace).
    @ViewBuilder func zoomSource(_ id: String, in namespace: Namespace.ID?) -> some View {
        if let namespace { matchedTransitionSource(id: id, in: namespace) } else { self }
    }

    @ViewBuilder func zoomTransition(sourceID: String?, in namespace: Namespace.ID) -> some View {
        if let sourceID { navigationTransition(.zoom(sourceID: sourceID, in: namespace)) } else { self }
    }
}

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct Chip: View {
    let label: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(isSelected ? 0 : 0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A row of chips for choosing one option, scrolling sideways when it doesn't fit.
struct ChipPicker<Value: Hashable & Identifiable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> Text

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(options) { option in
                    Chip(label: label(option), isSelected: option == selection) { selection = option }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .haptic(.selection, trigger: selection)
    }
}

/// A slider with its value shown, read by VoiceOver as one adjustable control.
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    var display: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(title)
                Spacer()
                Text(display(value)).foregroundStyle(.secondary).monospacedDigit()
            }
            .accessibilityHidden(true)
            Group {
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
            }
            .accessibilityLabel(title)
            .accessibilityValue(display(value))
        }
    }
}

/// Shrinks fixed-size content to fit, keeping proportions exact so previews stay true to the widget.
struct Fitted<Content: View>: View {
    let natural: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / natural.width, proxy.size.height / natural.height, 1)
            content
                .frame(width: natural.width, height: natural.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// Decoded preview photos, cached by name and size so grids scroll smoothly.
enum PreviewPhotos {
    private static let cache = NSCache<NSString, CGImage>()

    static func load(_ name: String?, root: URL, maxPixels: Int) async -> PhotoState {
        guard let name else { return .none }
        let key = "\(name)@\(maxPixels)" as NSString
        if let image = cache.object(forKey: key) { return .ready(image) }
        let state = await Task.detached(priority: .userInitiated) { PhotoFiles.load(name, root: root, maxPixels: maxPixels) }.value
        if case .ready(let image) = state { cache.setObject(image, forKey: key) }
        return state
    }
}

/// A design drawn exactly as the widget draws it, at true size, scaled down to fit.
struct DesignPreview: View {
    let design: WidgetDesign
    var size: DesignSize?
    var maxPixels = 900

    private var store: DesignStore { .shared }
    @State private var photo = PhotoState.loading

    var body: some View {
        let size = size ?? design.size
        let screen = Screen.size
        Fitted(natural: WidgetCanvas.naturalSize(size, screen: screen)) {
            WidgetCanvas(design: design, size: size, photo: photo, screen: screen)
        }
        .task(id: design.usesPhoto ? design.photo.imageName ?? "" : nil) {
            photo = design.usesPhoto ? await PreviewPhotos.load(design.photo.imageName, root: store.root, maxPixels: maxPixels) : .none
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of \(design.name), \(design.summary)")
    }
}

/// Infly's mark: an "i" made of two glass widget tiles.
struct InflyMark: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            VStack(spacing: width * 0.24) {
                tile(width: width, height: width, radius: width * 0.29)
                tile(width: width, height: width * 2.17, radius: width * 0.31)
            }
        }
        .aspectRatio(184 / 628, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func tile(width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.55)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0)], startPoint: .top, endPoint: .center), lineWidth: 1.5))
            .frame(width: width, height: height)
            .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 8)
    }
}

extension RGBA {
    init(_ color: Color) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
    }
}

extension Bundle {
    var version: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
}
