import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Infly

/// Storage tests run against a throwaway folder, standing in for the App Group container.
@MainActor
final class DesignStoreTests {
    let root = URL.temporaryDirectory.appending(path: "InflyTests-\(UUID().uuidString)")

    deinit { try? FileManager.default.removeItem(at: root) }

    @Test func savedDesignsSurviveARelaunch() {
        let store = DesignStore(root: root)
        var design = Presets.all[0].makeDesign()
        design.name = "Morning"
        store.save(design)

        let relaunched = DesignStore(root: root)
        #expect(relaunched.designs.map(\.id) == [design.id])
        #expect(relaunched.designs.first?.name == "Morning")
        #expect(relaunched.problem == nil)
    }

    @Test func widgetExtensionReadsWhatTheAppSaved() throws {
        let store = DesignStore(root: root)
        let design = Presets.all[1].makeDesign()
        store.save(design)

        // The widget extension calls this same reader on the shared App Group folder.
        let read = try DesignStore.read(from: root)
        #expect(read.first?.id == design.id)
        #expect(read.first?.style == design.style)
        #expect(read.first?.clock == design.clock)
    }

    @Test func savingAnEditedDesignUpdatesItInPlace() {
        let store = DesignStore(root: root)
        var design = Presets.all[2].makeDesign()
        store.save(design)
        design.text.text = "Changed"
        store.save(design)

        #expect(store.designs.count == 1)
        #expect(DesignStore(root: root).designs.first?.text.text == "Changed")
    }

    @Test func duplicateRenameAndDelete() {
        let store = DesignStore(root: root)
        let design = Presets.all[0].makeDesign()
        store.save(design)

        let copy = store.duplicate(design)
        #expect(copy.id != design.id)
        #expect(copy.name == "\(design.name) Copy")

        store.rename(copy.id, to: "  Evening  ")
        #expect(store.designs.first { $0.id == copy.id }?.name == "Evening")
        store.rename(copy.id, to: "   ")
        #expect(store.designs.first { $0.id == copy.id }?.name == "Evening")

        store.delete(design.id)
        #expect(DesignStore(root: root).designs.map(\.id) == [copy.id])
    }

    @Test func repeatedNamesGetNumbered() {
        let store = DesignStore(root: root)
        let design = Presets.all[0].makeDesign()
        store.save(design)
        #expect(store.uniqueName(design.name) == "\(design.name) 2")
        #expect(store.uniqueName("Something New") == "Something New")
    }

    @Test func photosStayUntilNoDesignUsesThem() throws {
        let store = DesignStore(root: root)
        let name = try PhotoFiles.store(Self.png(width: 64, height: 48), in: store.imagesURL)
        var design = Presets.blank(.photo).makeDesign()
        design.photo.imageName = name
        store.save(design)
        let copy = store.duplicate(design)

        store.delete(design.id)
        #expect(PhotoFiles.url(for: name, root: root) != nil)
        store.delete(copy.id)
        #expect(PhotoFiles.url(for: name, root: root) == nil)
    }

    @Test func missingPhotosAreReportedNotFatal() {
        guard case .missing = PhotoFiles.load("gone.jpg", root: root, maxPixels: 100) else {
            Issue.record("A deleted photo should load as .missing")
            return
        }
        guard case .none = PhotoFiles.load(nil, root: root, maxPixels: 100) else {
            Issue.record("No photo should load as .none")
            return
        }
    }

    @Test func storedPhotosAreDownsized() throws {
        let name = try PhotoFiles.store(Self.png(width: 3000, height: 1000), in: DesignStore.imagesURL(in: root))
        guard case .ready(let image) = PhotoFiles.load(name, root: root, maxPixels: 4000) else {
            Issue.record("The stored photo should load")
            return
        }
        #expect(max(image.width, image.height) == PhotoFiles.maxStoredPixels)
    }

    @Test func unreadableDataIsSetAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: root.appending(path: "designs.json"))

        let store = DesignStore(root: root)
        #expect(store.designs.isEmpty)
        #expect(store.problem != nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path(percentEncoded: false))
        #expect(files.contains { $0.hasPrefix("designs-unreadable-") })
    }

    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

@MainActor
struct EditorModelTests {
    @Test func undoRedoAndResetToPreset() throws {
        let preset = try #require(Presets.preset(id: "frost"))
        let model = EditorModel(design: preset.makeDesign(), isNew: true)
        #expect(!model.hasChanges)

        model.design.style.font = .serif
        #expect(model.canUndo && model.hasChanges)
        model.undo()
        #expect(model.design.style.font == preset.template.style.font)
        #expect(model.canRedo)
        model.redo()
        #expect(model.design.style.font == .serif)

        model.design.clock.label = "Home"
        model.resetToPreset()
        #expect(model.design.style == preset.template.style)
        #expect(model.design.clock.label == "Home")
    }
}

struct LogicTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    @Test func countdownCountsCalendarDaysAcrossDaylightSaving() {
        // Clocks spring forward on March 8, 2026 in New York.
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        var content = CountdownContent()
        content.date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        #expect(content.days(from: now, calendar: calendar) == 3)

        content.date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 1))!
        #expect(content.days(from: now, calendar: calendar) == 0)
        #expect(content.phrase(days: 0) == "is today")
        #expect(content.phrase(days: 1) == "is tomorrow")
        #expect(content.phrase(days: -2) == "was 2 days ago")
        #expect(content.caption(days: 1) == "day until \(content.title)")
    }

    @Test func timelineRefreshesAtMidnightAndAtTheEvent() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 15))!
        var design = Presets.blank(.countdown).makeDesign()
        design.countdown.date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!

        let dates = TimelinePlan.dates(for: design, from: now, calendar: calendar)
        #expect(dates.first == now)
        #expect(dates.contains(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!))
        #expect(dates.contains(design.countdown.date))
        #expect(dates == dates.sorted())
        #expect(TimelinePlan.dates(for: nil, from: now, calendar: calendar).count == 2)
    }

    @Test func cropAlwaysCoversTheWidget() {
        let frame = CGSize(width: 338, height: 158)
        for focus in [CGPoint.zero, CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.3), CGPoint(x: -3, y: 9)] {
            for zoom in [0.5, 1, 2.5] {
                let rect = PhotoCrop.layout(image: CGSize(width: 1600, height: 1200), frame: frame, focus: focus, zoom: zoom)
                #expect(rect.minX <= 0.001 && rect.minY <= 0.001)
                #expect(rect.maxX >= frame.width - 0.001 && rect.maxY >= frame.height - 0.001)
            }
        }
    }

    @Test func automaticTextColorStaysReadable() {
        var design = Presets.blank(.text).makeDesign()
        design.style.background = .solid(0xFFD84D)
        #expect(design.textRGBA(dark: false) == .ink)
        design.style.background = .gradient(0x22B8A8, 0x0B5370)
        #expect(design.textRGBA(dark: false) == .white)
        design.style.background = BackgroundStyle()
        #expect(design.textRGBA(dark: true) == .white)
        #expect(design.textRGBA(dark: false) == .ink)
        design.style.background.fill = .photo
        #expect(design.usesPhoto)
        #expect(design.textRGBA(dark: false) == .white)
        design.size = .rectangular
        #expect(!design.usesPhoto, "The Lock Screen never shows backgrounds")
    }

    @Test func presetsAreConsistent() {
        let presets = Presets.all + Presets.blanks
        #expect(Set(presets.map(\.id)).count == presets.count)
        for preset in presets {
            #expect(preset.template.kind.sizes.contains(preset.template.size), "\(preset.id) uses a size its type can't show")
            #expect(preset.template.presetID == preset.id)
        }
        for collection in Presets.collections {
            #expect(collection.presets.count == collection.presetIDs.count)
        }
        #expect(Presets.starterIDs.allSatisfy { Presets.preset(id: $0) != nil })
        #expect(WidgetKind.allCases.allSatisfy { Presets.blank($0).template.kind == $0 })
    }

    @Test func appGroupComesFromTheSigningProfile() throws {
        let profile = URL.temporaryDirectory.appending(path: "embedded-\(UUID().uuidString).mobileprovision")
        defer { try? FileManager.default.removeItem(at: profile) }
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>Entitlements</key><dict>
        <key>com.apple.security.application-groups</key><array><string>group.resigned.infly.ABC123</string></array>
        </dict></dict></plist>
        """
        // Real profiles wrap the plist in binary signature data.
        try (Data([0x30, 0x80, 0x06, 0x09]) + Data(plist.utf8) + Data([0x00, 0xA0, 0x82])).write(to: profile)
        #expect(SharedContainer.signedGroupID(profile: profile) == "group.resigned.infly.ABC123")
        #expect(SharedContainer.signedGroupID(profile: nil) == nil)
        #expect(SharedContainer.signedGroupID(profile: URL.temporaryDirectory.appending(path: "missing.mobileprovision")) == nil)
    }

    @Test func widgetSizesMatchKnownScreens() {
        #expect(WidgetMetrics.size(for: .small, screen: CGSize(width: 393, height: 852)) == CGSize(width: 158, height: 158))
        #expect(WidgetMetrics.size(for: .large, screen: CGSize(width: 430, height: 932)) == CGSize(width: 364, height: 382))
        #expect(WidgetMetrics.size(for: .medium, screen: CGSize(width: 667, height: 375)) == CGSize(width: 321, height: 148))
    }
}
