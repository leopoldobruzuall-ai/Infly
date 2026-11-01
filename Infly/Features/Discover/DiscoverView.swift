import SwiftUI

struct DiscoverView: View {
    @State private var category: PresetCategory?
    @State private var kind: WidgetKind?
    @State private var size: SizeFilter?
    @State private var query = ""

    private var isFiltering: Bool { category != nil || kind != nil || size != nil || !query.isEmpty }

    private var presets: [Preset] {
        Presets.all.filter { preset in
            (category == nil || preset.category == category)
                && (kind == nil || preset.template.kind == kind)
                && (size?.matches(preset.template.size) ?? true)
                && (query.isEmpty || [preset.name, preset.blurb, preset.category.title, preset.template.kind.title].contains { $0.localizedStandardContains(query) })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if !isFiltering {
                        FeaturedCollections()
                    }
                    categories
                    if presets.isEmpty {
                        noMatches
                    } else {
                        CardGrid(items: presets, size: \.template.size) { PresetCard(preset: $0) }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.xxl)
            }
            .background(AppBackdrop())
            .navigationTitle("Discover")
            .searchable(text: $query, prompt: "Search styles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FilterMenu(kind: $kind, size: $size)
                }
            }
            .navigationDestination(for: PresetCollection.self) { CollectionView(collection: $0) }
        }
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                Chip(label: Text("All"), isSelected: category == nil) { category = nil }
                ForEach(PresetCategory.allCases) { option in
                    Chip(label: Text(option.title), isSelected: category == option) { category = category == option ? nil : option }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .haptic(.selection, trigger: category)
    }

    @ViewBuilder private var noMatches: some View {
        if query.isEmpty {
            ContentUnavailableView {
                Label("No Styles Match", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("Try a different type, size or category.")
            } actions: {
                Button("Clear Filters") {
                    category = nil
                    kind = nil
                    size = nil
                }
            }
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}

enum SizeFilter: String, CaseIterable, Identifiable {
    case small, medium, large, lockScreen

    var id: Self { self }
    var title: String { self == .lockScreen ? "Lock Screen" : rawValue.capitalized }

    func matches(_ size: DesignSize) -> Bool {
        switch self {
        case .small: size == .small
        case .medium: size == .medium
        case .large: size == .large
        case .lockScreen: size.isLockScreen
        }
    }
}

/// Type and size filters. Pass nil for `kind` where type has its own chips.
struct FilterMenu: View {
    var kind: Binding<WidgetKind?>?
    @Binding var size: SizeFilter?

    private var isActive: Bool { kind?.wrappedValue != nil || size != nil }

    var body: some View {
        Menu {
            if let kind {
                Section("Type") {
                    Picker("Type", selection: kind) {
                        Text("All Types").tag(WidgetKind?.none)
                        ForEach(WidgetKind.allCases) { Label($0.title, systemImage: $0.symbol).tag(WidgetKind?.some($0)) }
                    }
                }
            }
            Section("Size") {
                Picker("Size", selection: $size) {
                    Text("All Sizes").tag(SizeFilter?.none)
                    ForEach(SizeFilter.allCases) { Text($0.title).tag(SizeFilter?.some($0)) }
                }
            }
            if isActive {
                Button("Clear Filters", systemImage: "xmark") {
                    kind?.wrappedValue = nil
                    size = nil
                }
            }
        } label: {
            Label("Filter", systemImage: isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

/// Lays out cards two to a row; wide widgets get a full row so their previews stay large.
struct CardGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    let size: (Item) -> DesignSize
    @ViewBuilder let card: (Item) -> Card

    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Row: Identifiable {
        let items: [Item]
        var id: Item.ID { items[0].id }
    }

    private var pairs: Bool { !typeSize.isAccessibilitySize }

    private var rows: [Row] {
        var rows: [Row] = []
        var pending: Item?
        for item in items {
            if size(item).isWide || !pairs {
                rows.append(Row(items: [item]))
            } else if let first = pending {
                rows.append(Row(items: [first, item]))
                pending = nil
            } else {
                pending = item
            }
        }
        if let pending { rows.append(Row(items: [pending])) }
        return rows
    }

    var body: some View {
        LazyVStack(spacing: Space.m) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: Space.m) {
                    ForEach(row.items) { card($0).frame(maxWidth: .infinity) }
                    if pairs && row.items.count == 1 && !size(row.items[0]).isWide {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}

struct PresetCard: View {
    let preset: Preset

    private var router: Router { .shared }
    @Environment(\.zoomNamespace) private var zoom

    var body: some View {
        Button {
            router.edit(preset.makeDesign(), isNew: true, from: preset.id)
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                DesignPreview(design: preset.template)
                    .frame(height: preset.template.size == .large ? 300 : 150)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name).font(.subheadline.weight(.semibold))
                    Text(preset.template.summary).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, Space.xs)
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .zoomSource(preset.id, in: zoom)
        .accessibilityLabel("\(preset.name), \(preset.template.summary)")
        .accessibilityHint(preset.blurb)
    }
}

private struct FeaturedCollections: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("Featured").font(.title3.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Space.m) {
                    ForEach(Presets.collections) { collection in
                        NavigationLink(value: collection) {
                            CollectionCard(collection: collection)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }
}

private struct CollectionCard: View {
    let collection: PresetCollection

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let text = collection.tint.legibleText(dark: scheme == .dark).color
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: -Space.l) {
                ForEach(Array(collection.presets.prefix(3).enumerated()), id: \.element.id) { index, preset in
                    DesignPreview(design: preset.template, size: preset.template.size.isLockScreen ? preset.template.size : .small, maxPixels: 400)
                        .frame(width: 92, height: 92)
                        .rotationEffect(.degrees(Double(index - 1) * 5))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title).font(.headline)
                Text(collection.subtitle).font(.subheadline).opacity(0.8).lineLimit(2)
            }
            .foregroundStyle(text)
        }
        .padding(Space.l)
        .containerRelativeFrame(.horizontal) { length, _ in min(length * 0.82, 360) }
        .frame(height: 220)
        .background(BackgroundFill(style: collection.tint, sheen: true))
        .clipShape(.rect(cornerRadius: Radius.card, style: .continuous))
        .containerShape(.rect(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collection.title) collection. \(collection.subtitle)")
    }
}

private struct CollectionView: View {
    let collection: PresetCollection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(collection.subtitle).foregroundStyle(.secondary)
                CardGrid(items: collection.presets, size: \.template.size) { PresetCard(preset: $0) }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(AppBackdrop())
        .navigationTitle(collection.title)
    }
}
