import SwiftUI

struct LibraryView: View {
    private var store: DesignStore { .shared }
    private var router: Router { .shared }
    @State private var kind: WidgetKind?
    @State private var size: SizeFilter?
    @State private var showsNewWidget = false
    @State private var chosenKind: WidgetKind?
    @State private var renaming: WidgetDesign?
    @State private var draftName = ""
    @State private var deleting: WidgetDesign?

    /// Most recently edited first, so the widget you just worked on is always at the top.
    private var designs: [WidgetDesign] {
        store.designs
            .filter { (kind == nil || $0.kind == kind) && (size?.matches($0.size) ?? true) }
            .sorted { $0.updated > $1.updated }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.designs.isEmpty {
                    EmptyLibrary(create: { showsNewWidget = true }, browse: { router.tab = .discover })
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            kinds
                            if designs.isEmpty {
                                ContentUnavailableView {
                                    Label("No Matches", systemImage: "line.3.horizontal.decrease.circle")
                                } description: {
                                    Text("None of your widgets match these filters.")
                                } actions: {
                                    Button("Clear Filters") {
                                        kind = nil
                                        size = nil
                                    }
                                }
                            } else {
                                CardGrid(items: designs, size: \.size) { design in
                                    DesignCard(design: design, rename: {
                                        draftName = design.name
                                        renaming = design
                                    }, delete: { deleting = design })
                                }
                            }
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, Space.xxl)
                    }
                }
            }
            .background(AppBackdrop())
            .navigationTitle("My Widgets")
            .toolbar {
                if !store.designs.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        FilterMenu(kind: nil, size: $size)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Widget", systemImage: "plus") { showsNewWidget = true }
                }
            }
            .sheet(isPresented: $showsNewWidget, onDismiss: openChosenKind) {
                NewWidgetSheet { choice in
                    chosenKind = choice
                    showsNewWidget = false
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Rename Widget", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let renaming { store.rename(renaming.id, to: draftName) }
                }
            }
            .confirmationDialog(
                Text("Delete “\(deleting?.name ?? "")”?"),
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible,
                presenting: deleting
            ) { design in
                Button("Delete Widget", role: .destructive) {
                    store.delete(design.id)
                    router.toast = "Deleted “\(design.name)”"
                }
            } message: { _ in
                Text("Any widget showing this design will ask you to pick another.")
            }
        }
    }

    private var kinds: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                Chip(label: Text("All"), isSelected: kind == nil) { kind = nil }
                ForEach(WidgetKind.allCases) { option in
                    Chip(label: Text(option.title), isSelected: kind == option) { kind = kind == option ? nil : option }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .haptic(.selection, trigger: kind)
    }

    /// The editor opens after the sheet is fully gone; presenting both at once is unreliable.
    private func openChosenKind() {
        guard let chosenKind else { return }
        self.chosenKind = nil
        router.edit(Presets.blank(chosenKind).makeDesign(), isNew: true)
    }
}

private struct DesignCard: View {
    let design: WidgetDesign
    let rename: () -> Void
    let delete: () -> Void

    private var store: DesignStore { .shared }
    private var router: Router { .shared }
    @Environment(\.zoomNamespace) private var zoom

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: Space.s) {
                DesignPreview(design: design)
                    .frame(height: design.size == .large ? 300 : 150)
                VStack(alignment: .leading, spacing: 2) {
                    Text(design.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(design.summary) · \(design.updated, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, Space.xs)
                .padding(.trailing, 36)
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(design.name), \(design.summary)")
        .accessibilityHint("Opens in the editor")
        .accessibilityAction(named: "Rename", rename)
        .accessibilityAction(named: "Duplicate", duplicate)
        .accessibilityAction(named: "Delete", delete)
        .overlay(alignment: .bottomTrailing) {
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .padding(Space.m)
                    .contentShape(.rect)
            }
            .accessibilityHidden(true)
        }
        .contextMenu { actions }
        .zoomSource(design.id.uuidString, in: zoom)
    }

    @ViewBuilder private var actions: some View {
        Button("Edit", systemImage: "slider.horizontal.3", action: edit)
        Button("Rename", systemImage: "pencil", action: rename)
        Button("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive, action: delete)
    }

    private func edit() {
        router.edit(design, isNew: false, from: design.id.uuidString)
    }

    private func duplicate() {
        store.duplicate(design)
        router.toast = "Duplicated “\(design.name)”"
    }
}

private struct EmptyLibrary: View {
    let create: () -> Void
    let browse: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                InflyMark().frame(height: 130)
                VStack(spacing: Space.s) {
                    Text("No widgets yet").font(.title2.weight(.semibold))
                    Text("Design one in a minute, save it, then add Infly to your Home Screen or Lock Screen.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: Space.m) {
                    Button(action: create) {
                        Text("Create your first widget").frame(maxWidth: 300)
                    }
                    .prominentStyle()
                    .controlSize(.large)
                    Button("Browse Discover", action: browse)
                }
            }
            .padding(Space.xxl)
            .padding(.top, Space.xxl)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct NewWidgetSheet: View {
    let choose: (WidgetKind) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.m)], spacing: Space.m) {
                    ForEach(WidgetKind.allCases) { kind in
                        Button { choose(kind) } label: {
                            VStack(alignment: .leading, spacing: Space.s) {
                                Image(systemName: kind.symbol).font(.title2).foregroundStyle(.tint)
                                Text(kind.title).font(.headline)
                                Text(kind.blurb).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .padding(Space.l)
                            .cardSurface()
                            .contentShape(.rect)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(Space.l)
            }
            .navigationTitle("New Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
