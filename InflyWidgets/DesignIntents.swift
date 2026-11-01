import AppIntents
import WidgetKit

/// Picks one saved design for a widget. Home and Lock Screen widgets get separate intents,
/// so each picker lists only the designs made for that placement.
protocol DesignChoosing: WidgetConfigurationIntent {
    static var forLockScreen: Bool { get }
    var designID: UUID? { get }
}

struct ChooseHomeDesign: DesignChoosing {
    static var title: LocalizedStringResource { "Choose Design" }
    static var description: IntentDescription? { IntentDescription("Pick which Infly design this widget shows.") }
    static var forLockScreen: Bool { false }

    @Parameter(title: "Design")
    var design: HomeDesign?

    var designID: UUID? { design?.id }
}

struct ChooseLockDesign: DesignChoosing {
    static var title: LocalizedStringResource { "Choose Design" }
    static var description: IntentDescription? { IntentDescription("Pick which Infly design this Lock Screen widget shows.") }
    static var forLockScreen: Bool { true }

    @Parameter(title: "Design")
    var design: LockDesign?

    var designID: UUID? { design?.id }
}

struct HomeDesign: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Design") }
    static var defaultQuery: HomeDesignQuery { HomeDesignQuery() }

    let id: UUID
    let name: String
    let summary: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(summary)") }

    init(_ design: WidgetDesign) {
        id = design.id
        name = design.name
        summary = design.summary
    }
}

struct LockDesign: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Design") }
    static var defaultQuery: LockDesignQuery { LockDesignQuery() }

    let id: UUID
    let name: String
    let summary: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)", subtitle: "\(summary)") }

    init(_ design: WidgetDesign) {
        id = design.id
        name = design.name
        summary = design.summary
    }
}

struct HomeDesignQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [HomeDesign] {
        DesignCatalog.designs(lockScreen: false).filter { identifiers.contains($0.id) }.map(HomeDesign.init)
    }

    func entities(matching string: String) async throws -> [HomeDesign] {
        DesignCatalog.designs(lockScreen: false).filter { $0.name.localizedStandardContains(string) }.map(HomeDesign.init)
    }

    func suggestedEntities() async throws -> [HomeDesign] {
        DesignCatalog.designs(lockScreen: false).map(HomeDesign.init)
    }

    func defaultResult() async -> HomeDesign? {
        DesignCatalog.designs(lockScreen: false).first.map(HomeDesign.init)
    }
}

struct LockDesignQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [LockDesign] {
        DesignCatalog.designs(lockScreen: true).filter { identifiers.contains($0.id) }.map(LockDesign.init)
    }

    func entities(matching string: String) async throws -> [LockDesign] {
        DesignCatalog.designs(lockScreen: true).filter { $0.name.localizedStandardContains(string) }.map(LockDesign.init)
    }

    func suggestedEntities() async throws -> [LockDesign] {
        DesignCatalog.designs(lockScreen: true).map(LockDesign.init)
    }

    func defaultResult() async -> LockDesign? {
        DesignCatalog.designs(lockScreen: true).first.map(LockDesign.init)
    }
}

enum DesignCatalog {
    /// Most recently edited first, which is also what an unconfigured widget shows.
    static func designs(lockScreen: Bool) -> [WidgetDesign] {
        guard let root = SharedContainer.url, let designs = try? DesignStore.read(from: root) else { return [] }
        return designs.filter { $0.size.isLockScreen == lockScreen }.sorted { $0.updated > $1.updated }
    }
}

struct DesignProvider<Intent: DesignChoosing>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DesignEntry {
        .sample(for: context.family)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> DesignEntry {
        let entry = entry(for: configuration, in: context, at: .now)
        // The widget gallery shows a sample until the user has a design of their own.
        return context.isPreview && entry.design == nil ? .sample(for: context.family) : entry
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<DesignEntry> {
        let now = Date.now
        let first = entry(for: configuration, in: context, at: now)
        let entries = TimelinePlan.dates(for: first.design, from: now).map { date in
            var entry = first
            entry.date = date
            return entry
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func entry(for configuration: Intent, in context: Context, at date: Date) -> DesignEntry {
        guard let root = SharedContainer.url else { return DesignEntry(date: date, status: .notShared) }
        let designs = (try? DesignStore.read(from: root)) ?? []
        let design: WidgetDesign?
        if let id = configuration.designID {
            design = designs.first { $0.id == id }
            if design == nil { return DesignEntry(date: date, status: .deleted) }
        } else {
            design = designs.filter { $0.size.isLockScreen == Intent.forLockScreen }.max { $0.updated < $1.updated }
        }
        guard let design else { return DesignEntry(date: date, status: .noDesigns) }
        guard design.usesPhoto else { return DesignEntry(date: date, design: design) }
        // Decode only the pixels the widget can show at this zoom (3x screens).
        let side = max(context.displaySize.width, context.displaySize.height) * 3 * design.photo.zoom
        let pixels = min(max(Int(side), 600), PhotoFiles.maxStoredPixels)
        return DesignEntry(date: date, design: design, photo: PhotoFiles.load(design.photo.imageName, root: root, maxPixels: pixels))
    }
}

struct DesignEntry: TimelineEntry {
    enum Status { case ready, noDesigns, deleted, notShared }

    var date: Date
    var design: WidgetDesign?
    var photo: PhotoState = .none
    var status = Status.ready

    static func sample(for family: WidgetFamily) -> DesignEntry {
        let id = switch family {
        case .systemMedium: "tide-line"
        case .systemLarge, .systemExtraLarge: "plum-night"
        case .accessoryCircular: "pocket-clock"
        case .accessoryRectangular: "next-up"
        case .accessoryInline: "inline-date"
        default: "frost"
        }
        let design = Presets.preset(id: id)?.template
        let photo = design?.usesPhoto == true ? PhotoFiles.load(design?.photo.imageName, root: .temporaryDirectory, maxPixels: 1200) : .none
        return DesignEntry(date: .now, design: design, photo: photo)
    }
}
