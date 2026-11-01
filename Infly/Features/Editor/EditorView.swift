import SwiftUI

enum EditorSection: String, CaseIterable, Identifiable {
    case content, style, layout
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct EditorView: View {
    private var store: DesignStore { .shared }
    private var router: Router { .shared }
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.hasSavedWidget) private var hasSavedWidget = false
    @State private var model: EditorModel
    @State private var section = EditorSection.content
    @State private var photo = PhotoState.none
    @State private var showsHint: Bool
    @State private var confirmsDiscard = false
    @State private var confirmsReset = false
    @State private var renaming = false
    @State private var draftName = ""

    init(request: EditorRequest) {
        _model = State(initialValue: EditorModel(design: request.design, isNew: request.isNew))
        _showsHint = State(initialValue: request.guided)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    PreviewStage(model: model, photo: photo, showsHint: $showsHint)
                        .frame(height: max(proxy.size.height * 0.44, 230))
                    ControlPanel(model: model, section: $section)
                }
            }
            .background(AppBackdrop())
            .navigationTitle(model.design.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                Button("Rename", systemImage: "pencil") {
                    draftName = model.design.name
                    renaming = true
                }
                if model.preset != nil {
                    Button("Reset to Preset", systemImage: "arrow.counterclockwise") { confirmsReset = true }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
            .confirmationDialog("Reset to “\(model.preset?.name ?? "")”?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset Style") { model.resetToPreset() }
            } message: {
                Text("The preset's colors, type and layout come back. Your words, photo and dates stay. You can undo this.")
            }
            .alert("Rename Widget", isPresented: $renaming) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) {}
                Button("Done") {
                    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { model.design.name = name }
                }
            }
            .task(id: model.design.usesPhoto ? model.design.photo.imageName ?? "" : nil) {
                guard model.design.usesPhoto else { return }
                photo = .loading
                photo = await PreviewPhotos.load(model.design.photo.imageName, root: store.root, maxPixels: PhotoFiles.maxStoredPixels)
            }
            .onChange(of: model.canUndo) { if model.canUndo { showsHint = false } }
        }
        .interactiveDismissDisabled(model.hasChanges)
    }

    private func cancel() {
        if model.hasChanges { confirmsDiscard = true } else { dismiss() }
    }

    private func save() {
        var design = model.design
        if design.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { design.name = design.kind.title }
        if model.isNew { design.name = store.uniqueName(design.name) }
        store.save(design)
        router.saveCount += 1
        if model.isNew { router.tab = .library }
        if hasSavedWidget {
            router.toast = model.isNew ? "Saved to My Widgets" : "Saved"
        } else {
            hasSavedWidget = true
            router.followUp = .guide(design)
        }
        dismiss()
    }
}

/// The live preview on a stand-in wallpaper, with size, appearance and history controls.
private struct PreviewStage: View {
    @Bindable var model: EditorModel
    let photo: PhotoState
    @Binding var showsHint: Bool

    @Environment(\.colorScheme) private var scheme
    @State private var previewScheme: ColorScheme?
    @State private var dragStart: CGPoint?
    @State private var zoomStart: Double?
    @State private var historyTaps = 0
    private let motion = MotionPreference()

    var body: some View {
        let design = model.design
        let screen = Screen.size
        let natural = WidgetCanvas.naturalSize(design.size, screen: screen)
        VStack(spacing: Space.m) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / natural.width, proxy.size.height / natural.height, 1)
                WidgetCanvas(design: design, size: design.size, photo: photo, screen: screen)
                    .environment(\.colorScheme, previewScheme ?? scheme)
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(.rect)
                    .gesture(cropGesture(scale: scale), including: design.usesPhoto ? .all : .subviews)
                    .animation(motion.animation(.smooth(duration: 0.35)), value: design.size)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Live preview of \(design.name), \(design.summary)")
            }
            .padding(.horizontal, Space.xl)

            if showsHint {
                Label("Make it yours, then tap Save.", systemImage: "hand.tap")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, Space.m)
                    .padding(.vertical, Space.s)
                    .glassSurface(in: Capsule())
                    .transition(.opacity)
            }

            HStack(spacing: Space.s) {
                sizeMenu
                Spacer(minLength: 0)
                if design.style.background.isAdaptive && design.kind != .photo && !design.size.isLockScreen {
                    Picker("Preview Appearance", selection: Binding(get: { previewScheme ?? scheme }, set: { previewScheme = $0 })) {
                        Label("Light", systemImage: "sun.max").labelStyle(.iconOnly).tag(ColorScheme.light)
                        Label("Dark", systemImage: "moon").labelStyle(.iconOnly).tag(ColorScheme.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 96)
                }
                history
            }
            .padding(.horizontal, Space.l)
        }
        .padding(.vertical, Space.m)
        .animation(motion.animation(), value: showsHint)
    }

    private var sizeMenu: some View {
        Menu {
            Picker("Size", selection: $model.design.size) {
                Section("Home Screen") {
                    ForEach(DesignSize.home) { Text($0.title).tag($0) }
                }
                if model.design.kind.sizes.contains(where: \.isLockScreen) {
                    Section("Lock Screen") {
                        ForEach(DesignSize.lock) { Text($0.title).tag($0) }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: model.design.size.isLockScreen ? "lock.fill" : "square.grid.2x2.fill")
                Text(model.design.size.title)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassSurface(in: Capsule(), interactive: true)
        }
        .accessibilityLabel("Widget size, \(model.design.size.title), \(model.design.size.placement)")
        .haptic(.selection, trigger: model.design.size)
    }

    private var history: some View {
        HStack(spacing: 0) {
            Button {
                model.undo()
                historyTaps += 1
            } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 40, height: 36)
            }
            .disabled(!model.canUndo)
            .opacity(model.canUndo ? 1 : 0.35)
            .accessibilityLabel("Undo")
            .keyboardShortcut("z", modifiers: .command)
            Button {
                model.redo()
                historyTaps += 1
            } label: {
                Image(systemName: "arrow.uturn.forward").frame(width: 40, height: 36)
            }
            .disabled(!model.canRedo)
            .opacity(model.canRedo ? 1 : 0.35)
            .accessibilityLabel("Redo")
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .buttonStyle(.plain)
        .font(.body.weight(.semibold))
        .glassSurface(in: Capsule(), interactive: true)
        .haptic(.impact(weight: .light), trigger: historyTaps)
    }

    /// Drag to reposition, pinch to zoom. Movement is converted from screen points to the photo's overflow.
    private func cropGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard case .ready(let image) = photo else { return }
                let start = dragStart ?? CGPoint(x: model.design.photo.focusX, y: model.design.photo.focusY)
                dragStart = start
                let frame = WidgetMetrics.size(for: model.design.size, screen: Screen.size)
                let overflow = PhotoCrop.overflow(image: CGSize(width: image.width, height: image.height), frame: frame, zoom: model.design.photo.zoom)
                var content = model.design.photo
                if overflow.width > 0 { content.focusX = PhotoCrop.clamp(start.x - value.translation.width / scale / overflow.width) }
                if overflow.height > 0 { content.focusY = PhotoCrop.clamp(start.y - value.translation.height / scale / overflow.height) }
                model.design.photo = content
            }
            .onEnded { _ in dragStart = nil }
            .simultaneously(with: MagnifyGesture()
                .onChanged { value in
                    let start = zoomStart ?? model.design.photo.zoom
                    zoomStart = start
                    model.design.photo.zoom = min(max(start * value.magnification, 1), 4)
                }
                .onEnded { _ in zoomStart = nil })
    }
}

/// Content, Style and Layout controls in a docked panel.
private struct ControlPanel: View {
    @Bindable var model: EditorModel
    @Binding var section: EditorSection

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(Prefs.solidPanels) private var solidPanels = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $section) {
                ForEach(EditorSection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Space.l)
            .padding(.top, Space.l)
            .padding(.bottom, Space.xs)

            Form {
                switch section {
                case .content: ContentControls(model: model)
                case .style: StyleControls(model: model)
                case .layout: LayoutControls(model: model)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: Radius.panel, topTrailingRadius: Radius.panel, style: .continuous)
            Group {
                if reduceTransparency || solidPanels {
                    shape.fill(Color(.systemGroupedBackground))
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 20, y: -4)
            .ignoresSafeArea(edges: .bottom)
        }
        .haptic(.selection, trigger: section)
    }
}
