import PhotosUI
import SwiftUI

struct ContentControls: View {
    @Bindable var model: EditorModel

    private var size: DesignSize { model.design.size }

    var body: some View {
        switch model.design.kind {
        case .clock: clock
        case .photo: photo
        case .text: text
        case .countdown: countdown
        }
    }

    @ViewBuilder private var clock: some View {
        if !size.isLockScreen {
            Section {
                ChipPicker(options: ClockContent.Layout.allCases, selection: $model.design.clock.layout) { Text($0.title) }
                if model.design.clock.offersDateToggle {
                    Toggle("Show Date", isOn: $model.design.clock.showsDate)
                }
            } header: {
                Text("Layout")
            } footer: {
                if model.design.clock.layout == .dayProgress {
                    Text("A bar fills as the day goes by.")
                }
            }
        } else if size == .rectangular {
            Section {
                Toggle("Show Date", isOn: $model.design.clock.showsDate)
            }
        }
        Section {
            NavigationLink {
                TimeZonePicker(zoneID: $model.design.clock.timeZoneID, label: $model.design.clock.label)
            } label: {
                LabeledContent("Time Zone", value: model.design.clock.timeZoneID.map(TimeZonePicker.city) ?? "Current Location")
            }
            TextField("Label (optional)", text: $model.design.clock.label)
        } header: {
            Text("Time Zone")
        } footer: {
            Text("Show another city's time, like a friend's or a team's.")
        }
    }

    @ViewBuilder private var photo: some View {
        PhotoControls(model: model)
        Section("Caption") {
            TextField("Caption (optional)", text: $model.design.photo.caption)
            Toggle("Show Date", isOn: $model.design.photo.showsDate)
        }
    }

    @ViewBuilder private var text: some View {
        if !size.isLockScreen {
            Section("Layout") {
                ChipPicker(options: TextContent.Layout.allCases, selection: $model.design.text.layout) { Text($0.title) }
            }
        }
        Section {
            TextField("Text", text: $model.design.text.text, axis: .vertical)
                .lineLimit(2...5)
            if let detail = detailPlaceholder {
                TextField(detail, text: $model.design.text.detail)
            }
        } header: {
            Text("Words")
        } footer: {
            Text("Short lines read best, especially on small widgets.")
        }
    }

    private var detailPlaceholder: String? {
        if size == .rectangular { return "Heading (optional)" }
        guard !size.isLockScreen else { return nil }
        switch model.design.text.layout {
        case .quote: return "Attribution (optional)"
        case .note: return "Heading (optional)"
        default: return nil
        }
    }

    @ViewBuilder private var countdown: some View {
        let content = model.design.countdown
        Section("Event") {
            TextField("Event name", text: $model.design.countdown.title)
            DatePicker("Date", selection: $model.design.countdown.date, displayedComponents: content.includesTime ? [.date, .hourAndMinute] : [.date])
            Toggle("Specific Time", isOn: $model.design.countdown.includesTime)
        }
        if size != .circular && size != .inline {
            Section {
                ChipPicker(options: CountdownContent.Layout.allCases, selection: $model.design.countdown.layout) { Text($0.title) }
            } header: {
                Text("Layout")
            }
        }
        if content.layout == .ring || size == .circular {
            Section {
                DatePicker("Start", selection: $model.design.countdown.start, in: ...content.date, displayedComponents: .date)
            } footer: {
                Text("The ring fills from this day to the event.")
            }
        }
        Section("Symbol") {
            SymbolPicker(selection: $model.design.countdown.symbol)
        }
    }
}

/// Choosing, cropping and toning the design's photo, for photo widgets and photo backgrounds.
private struct PhotoControls: View {
    @Bindable var model: EditorModel

    @State private var pickerItem: PhotosPickerItem?
    @State private var importing = false
    @State private var importFailed = false

    var body: some View {
        let pickTitle = model.design.photo.imageName == nil ? "Choose Photo" : "Replace Photo"
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack {
                    Label(pickTitle, systemImage: "photo.on.rectangle")
                    Spacer()
                    if importing { ProgressView() }
                }
            }
            .disabled(importing)
        } footer: {
            Text("Infly only receives the photo you pick. It's resized and kept on this iPhone.")
        }
        .onChange(of: pickerItem) { _, item in importPhoto(item) }
        .alert("Couldn't Use That Photo", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("It may still be downloading from iCloud, or be in a format Infly can't read. Try another photo.")
        }

        if model.design.photo.imageName != nil {
            Section {
                LabeledSlider(title: "Zoom", value: $model.design.photo.zoom, range: 1...4) { String(format: "%.1f×", $0) }
                LabeledSlider(title: "Horizontal", value: $model.design.photo.focusX, range: 0...1)
                LabeledSlider(title: "Vertical", value: $model.design.photo.focusY, range: 0...1)
                Button("Center Photo") {
                    var content = model.design.photo
                    content.focusX = 0.5
                    content.focusY = 0.5
                    content.zoom = 1
                    model.design.photo = content
                }
            } header: {
                Text("Crop")
            } footer: {
                Text("You can also drag the preview to reposition, and pinch it to zoom.")
            }
        }

        Section {
            LabeledSlider(title: "Shade", value: $model.design.photo.shade, range: 0...0.7)
            ChipPicker(options: PhotoContent.Filter.allCases, selection: $model.design.photo.filter) { Text($0.title) }
        } header: {
            Text("Tone")
        } footer: {
            Text("Shade darkens the photo behind your text so it stays readable.")
        }
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        importing = true
        Task {
            defer {
                importing = false
                pickerItem = nil
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoError.unreadable }
                let folder = DesignStore.shared.imagesURL
                let name = try await Task.detached(priority: .userInitiated) { try PhotoFiles.store(data, in: folder) }.value
                var content = model.design.photo
                content.imageName = name
                content.focusX = 0.5
                content.focusY = 0.5
                content.zoom = 1
                model.design.photo = content
            } catch {
                importFailed = true
            }
        }
    }
}

struct StyleControls: View {
    @Bindable var model: EditorModel

    @Environment(\.colorScheme) private var scheme

    private var isLock: Bool { model.design.size.isLockScreen }
    private var isPhoto: Bool { model.design.kind == .photo }

    var body: some View {
        if !isLock && !isPhoto {
            Section("Quick Styles") {
                PaletteRow { model.design.apply($0) }
            }
        }

        Section {
            ChipPicker(options: FontChoice.allCases, selection: $model.design.style.font) { Text($0.title).font($0.font(size: 15, weight: .medium)) }
            LabeledSlider(title: "Weight", value: weightIndex, range: 0...Double(WeightChoice.allCases.count - 1), step: 1) { WeightChoice.allCases[Int($0.rounded())].title }
            LabeledSlider(title: "Text Size", value: $model.design.style.textScale, range: 0.7...1.4)
        } header: {
            Text("Type")
        } footer: {
            if isLock {
                Text("iOS tints Lock Screen widgets to match your wallpaper, so colors and backgrounds aren't used there. Type still applies.")
            }
        }

        if !isLock {
            Section {
                Toggle("Automatic Color", isOn: automaticText)
                if model.design.style.textColor != nil {
                    ColorPicker("Text Color", selection: textColor, supportsOpacity: false)
                }
            } header: {
                Text("Text Color")
            } footer: {
                Text("Automatic picks black or white, whichever is easier to read on your background.")
            }
        }

        if !isLock && !isPhoto {
            Section {
                Picker("Fill", selection: $model.design.style.background.fill) {
                    ForEach(BackgroundStyle.Fill.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                switch model.design.style.background.fill {
                case .automatic:
                    EmptyView()
                case .solid:
                    ColorPicker("Color", selection: model.color(\.style.background.colors[0]), supportsOpacity: false)
                case .gradient:
                    ColorPicker("Start", selection: model.color(\.style.background.colors[0]), supportsOpacity: false)
                    ColorPicker("End", selection: model.color(\.style.background.colors[1]), supportsOpacity: false)
                    LabeledSlider(title: "Angle", value: $model.design.style.background.angle, range: 0...360, step: 5) { "\(Int($0))°" }
                case .aurora:
                    ColorPicker("Base", selection: model.color(\.style.background.colors[0]), supportsOpacity: false)
                    ColorPicker("Glow", selection: model.color(\.style.background.colors[1]), supportsOpacity: false)
                    ColorPicker("Accent", selection: model.color(\.style.background.colors[2]), supportsOpacity: false)
                case .photo:
                    EmptyView()
                }
            } header: {
                Text("Background")
            } footer: {
                switch model.design.style.background.fill {
                case .automatic: Text("Follows Light and Dark Mode: white by day, charcoal at night.")
                case .aurora: Text("Two soft glows over a base color.")
                case .photo: Text("A photo of yours fills the widget behind everything else.")
                default: EmptyView()
                }
            }
            if model.design.style.background.fill == .photo {
                PhotoControls(model: model)
            }
        }
    }

    private var weightIndex: Binding<Double> {
        Binding(
            get: { Double(WeightChoice.allCases.firstIndex(of: model.design.style.weight) ?? 0) },
            set: { model.design.style.weight = WeightChoice.allCases[Int($0.rounded())] }
        )
    }

    private var automaticText: Binding<Bool> {
        Binding(
            get: { model.design.style.textColor == nil },
            set: { model.design.style.textColor = $0 ? nil : model.design.textRGBA(dark: scheme == .dark) }
        )
    }

    private var textColor: Binding<Color> {
        Binding(
            get: { model.design.textColor(dark: scheme == .dark) },
            set: { model.design.style.textColor = RGBA($0) }
        )
    }
}

struct LayoutControls: View {
    @Bindable var model: EditorModel

    var body: some View {
        switch model.design.size {
        case .small, .medium, .large:
            Section("Position") {
                PositionGrid(selection: $model.design.style.position)
            }
            Section("Spacing") {
                LabeledSlider(title: "Padding", value: $model.design.style.padding, range: 8...28, step: 1) { "\(Int($0)) pt" }
                LabeledSlider(title: "Line Spacing", value: $model.design.style.spacing, range: 0...16, step: 1) { "\(Int($0)) pt" }
            }
            Section {
                Toggle("Frame", isOn: $model.design.style.showsFrame)
                if model.design.kind != .photo {
                    Toggle("Sheen", isOn: $model.design.style.showsSheen)
                }
                Toggle("Text Shadow", isOn: $model.design.style.showsShadow)
            } header: {
                Text("Finishing Touches")
            } footer: {
                Text("Frame draws a fine line that follows the widget's corners. Sheen adds soft light: widgets can't blur your wallpaper, so it suggests glass instead. For true glass on iOS 26, choose the Clear look when you customize your Home Screen.")
            }
        case .rectangular:
            Section("Alignment") {
                Picker("Alignment", selection: $model.design.style.position) {
                    Label("Left", systemImage: "text.alignleft").labelStyle(.iconOnly).tag(ContentPosition.leading)
                    Label("Center", systemImage: "text.aligncenter").labelStyle(.iconOnly).tag(ContentPosition.center)
                    Label("Right", systemImage: "text.alignright").labelStyle(.iconOnly).tag(ContentPosition.trailing)
                }
                .pickerStyle(.segmented)
            }
        case .circular, .inline:
            Section {
                Text("iOS lays out this Lock Screen size for you. Try Rectangular for alignment options.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A 3×3 grid that mirrors where content sits in the widget.
private struct PositionGrid: View {
    @Binding var selection: ContentPosition

    var body: some View {
        Grid(horizontalSpacing: Space.s, verticalSpacing: Space.s) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        cell(ContentPosition.allCases[row * 3 + column])
                    }
                }
            }
        }
        .padding(.vertical, Space.xs)
        .haptic(.selection, trigger: selection)
    }

    private func cell(_ position: ContentPosition) -> some View {
        let selected = position == selection
        return Button {
            selection = position
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color.accentColor : Color.secondary.opacity(0.15))
                .frame(height: 36)
                .overlay {
                    Capsule()
                        .fill(selected ? Color.white : Color.secondary.opacity(0.5))
                        .frame(width: 18, height: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
                        .padding(9)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(position.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PaletteRow: View {
    let apply: (Palette) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.m) {
                ForEach(Palette.all) { palette in
                    Button { apply(palette) } label: {
                        VStack(spacing: Space.xs) {
                            BackgroundFill(style: palette.background)
                                .frame(width: 44, height: 44)
                                .clipShape(.rect(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.12)))
                                .overlay(Text("Aa").font(.caption.weight(.semibold)).foregroundStyle((palette.text ?? palette.background.legibleText(dark: false)).color))
                            Text(palette.name).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(palette.name) style")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

private struct SymbolPicker: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(CountdownContent.symbols, id: \.self) { symbol in
                    let selected = symbol == selection
                    Button { selection = symbol } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                            .background(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .haptic(.selection, trigger: selection)
    }
}

struct TimeZonePicker: View {
    @Binding var zoneID: String?
    @Binding var label: String

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    static func city(_ id: String) -> String {
        id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
    }

    private var zones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        return query.isEmpty ? all : all.filter { $0.localizedStandardContains(query) || Self.city($0).localizedStandardContains(query) }
    }

    var body: some View {
        List {
            if query.isEmpty {
                row(title: "Current Location", detail: TimeZone.current.identifier, id: nil)
            }
            ForEach(zones, id: \.self) { id in
                row(title: Self.city(id), detail: id, id: id)
            }
        }
        .searchable(text: $query, prompt: "City or region")
        .navigationTitle("Time Zone")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: String, detail: String, id: String?) -> some View {
        let selected = id == zoneID
        return Button {
            // Keep a custom label; replace one that was just the old city's name.
            if label.isEmpty || label == zoneID.map(Self.city) { label = id.map(Self.city) ?? "" }
            zoneID = id
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
