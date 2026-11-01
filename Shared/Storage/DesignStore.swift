import Foundation
import Observation
import WidgetKit

/// The App Group container the app and widget extension share.
enum SharedContainer {
    /// Sideloading tools re-sign with App Group IDs of their own, so the group in the embedded
    /// provisioning profile wins. App Store builds have no profile and use Info.plist's value,
    /// which the build fills in from Config/Infly.xcconfig.
    static let groupID: String? = {
        if let signed = signedGroupID() { return signed }
        let declared = Bundle.main.object(forInfoDictionaryKey: "InflyAppGroup") as? String ?? ""
        return declared.isEmpty ? nil : declared // Mac builds declare none.
    }()

    static var url: URL? {
        groupID.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    /// The first App Group in a provisioning profile: a signed blob with a plain XML plist inside.
    static func signedGroupID(profile: URL? = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision")) -> String? {
        guard let profile, let data = try? Data(contentsOf: profile),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else { return nil }
        return groups.first
    }
}

/// Saved designs, persisted as one JSON file the widget extension reads directly.
@MainActor @Observable
final class DesignStore {
    private(set) var designs: [WidgetDesign] = []
    /// A message for the user when saved data couldn't be read or written.
    var problem: String?
    let root: URL
    /// False when the App Group is missing, so widgets can't see these designs.
    let isShared: Bool

    init(root: URL, isShared: Bool = true) {
        self.root = root
        self.isShared = isShared
        load()
    }

    /// The app's store. Views read it directly rather than through .environment (see Router.shared).
    static let shared: DesignStore = {
        if let container = SharedContainer.url { return DesignStore(root: container) }
        return DesignStore(root: .applicationSupportDirectory.appending(path: "Infly"), isShared: false)
    }()

    var imagesURL: URL { Self.imagesURL(in: root) }
    private var fileURL: URL { root.appending(path: "designs.json") }

    nonisolated static func imagesURL(in root: URL) -> URL { root.appending(path: "Images", directoryHint: .isDirectory) }

    /// Used by the widget extension too. No file yet means no designs.
    nonisolated static func read(from root: URL) throws -> [WidgetDesign] {
        let url = root.appending(path: "designs.json")
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode(Library.self, from: Data(contentsOf: url)).designs
    }

    func load() {
        do {
            designs = try Self.read(from: root)
        } catch {
            // Never let the next save overwrite data we couldn't read: set it aside first.
            let backup = root.appending(path: "designs-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            designs = []
            problem = "Some saved widgets couldn't be read. A copy was kept in Infly's storage."
        }
    }

    func save(_ design: WidgetDesign) {
        var design = design
        design.updated = .now
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            designs[index] = design
        } else {
            designs.insert(design, at: 0)
        }
        persist()
    }

    @discardableResult
    func duplicate(_ design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.id = UUID()
        copy.name = "\(design.name) Copy"
        copy.created = .now
        save(copy)
        return copy
    }

    /// "Frost", then "Frost 2", so widget pickers can tell saved designs apart.
    func uniqueName(_ base: String) -> String {
        let names = Set(designs.map(\.name))
        guard names.contains(base) else { return base }
        var number = 2
        while names.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

    func rename(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = designs.firstIndex(where: { $0.id == id }) else { return }
        designs[index].name = name
        designs[index].updated = .now
        persist()
    }

    func delete(_ id: UUID) {
        designs.removeAll { $0.id == id }
        persist()
        removeOrphanedImages()
    }

    /// Photos are shared between duplicates, so a file goes only when no design uses it.
    func removeOrphanedImages() {
        let used = Set(designs.compactMap(\.photo.imageName))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: imagesURL.path(percentEncoded: false))) ?? []
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: imagesURL.appending(path: file))
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try JSONEncoder().encode(Library(designs: designs)).write(to: fileURL, options: .atomic)
        } catch {
            problem = "Infly couldn't save your changes. Free up some storage, then try again."
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct Library: Codable {
    var version = 1
    var designs: [WidgetDesign]
}
