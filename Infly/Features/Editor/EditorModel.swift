import SwiftUI

/// The design being edited, with undo and redo.
@MainActor @Observable
final class EditorModel {
    var design: WidgetDesign {
        didSet {
            if !restoring && design != oldValue { record(oldValue) }
        }
    }

    let original: WidgetDesign
    let isNew: Bool
    private(set) var undoStack: [WidgetDesign] = []
    private(set) var redoStack: [WidgetDesign] = []
    @ObservationIgnored private var restoring = false
    @ObservationIgnored private var lastEdit = Date.distantPast

    init(design: WidgetDesign, isNew: Bool) {
        var design = design
        // Color pickers bind to three slots; older or hand-edited data may have fewer.
        while design.style.background.colors.count < 3 {
            design.style.background.colors.append(design.style.background.colors.last ?? .ink)
        }
        self.design = design
        original = design
        self.isNew = isNew
    }

    var hasChanges: Bool { design != original }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var preset: Preset? { Presets.preset(id: design.presetID) }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(design)
        restore(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(design)
        restore(next)
    }

    /// Brings back the preset's look and layout. Words, photos and dates stay.
    func resetToPreset() {
        guard let template = preset?.template else { return }
        var reset = design
        reset.size = template.size
        reset.style = template.style
        reset.clock.layout = template.clock.layout
        reset.clock.showsDate = template.clock.showsDate
        reset.text.layout = template.text.layout
        reset.countdown.layout = template.countdown.layout
        reset.photo.filter = template.photo.filter
        reset.photo.shade = template.photo.shade
        design = reset
    }

    func color(_ keyPath: WritableKeyPath<WidgetDesign, RGBA>) -> Binding<Color> {
        Binding(get: { self.design[keyPath: keyPath].color }, set: { self.design[keyPath: keyPath] = RGBA($0) })
    }

    private func record(_ previous: WidgetDesign) {
        // Slider drags and typing arrive as many tiny edits; a pause starts a new undo step.
        if Date.now.timeIntervalSince(lastEdit) > 0.6 {
            undoStack.append(previous)
            if undoStack.count > 100 { undoStack.removeFirst() }
        }
        lastEdit = .now
        redoStack.removeAll()
    }

    private func restore(_ design: WidgetDesign) {
        restoring = true
        self.design = design
        restoring = false
        lastEdit = .distantPast
    }
}
