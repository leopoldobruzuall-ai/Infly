import SwiftUI
import WidgetKit

@main
struct InflyWidgets: WidgetBundle {
    var body: some Widget {
        HomeScreenWidget()
        LockScreenWidget()
    }
}

struct HomeScreenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "InflyHomeScreen", intent: ChooseHomeDesign.self, provider: DesignProvider<ChooseHomeDesign>()) { entry in
            DesignWidgetView(entry: entry)
        }
        .configurationDisplayName("Infly")
        .description("Shows a design you made in Infly. Touch and hold it, then choose Edit Widget to pick a design.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // Each design carries its own padding, so in-app previews match the widget exactly.
        .contentMarginsDisabled()
    }
}

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "InflyLockScreen", intent: ChooseLockDesign.self, provider: DesignProvider<ChooseLockDesign>()) { entry in
            DesignWidgetView(entry: entry)
        }
        .configurationDisplayName("Infly Lock Screen")
        .description("Shows a Lock Screen design you made in Infly.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct DesignWidgetView: View {
    let entry: DesignEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let size = family.designSize
        if let design = entry.design {
            DesignView(design: design, size: size, date: entry.date, photo: entry.photo)
                .containerBackground(for: .widget) {
                    if !size.isLockScreen { DesignBackground(design: design, photo: entry.photo) }
                }
                .widgetURL(URL(string: "infly://design/\(design.id.uuidString)"))
        } else {
            StatusView(status: entry.status, size: size)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "infly://library"))
        }
    }
}

/// Shown when there's nothing to draw yet, or the chosen design is gone.
private struct StatusView: View {
    let status: DesignEntry.Status
    let size: DesignSize

    var body: some View {
        switch size {
        case .inline:
            Label(title, systemImage: symbol)
        case .circular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: symbol).font(.title3)
            }
            .accessibilityLabel(title)
        case .rectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Infly", systemImage: symbol).font(.caption.weight(.semibold))
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: symbol).font(.title2).foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text(title).font(.headline)
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var title: String {
        switch status {
        case .deleted: "Design deleted"
        case .notShared: "Paste a design code"
        default: "Make a widget"
        }
    }

    private var message: String {
        switch status {
        case .deleted: "Touch and hold, then Edit Widget to pick another design."
        case .notShared: "In Infly, tap Copy Widget Code on a design. Then touch and hold here, choose Edit Widget, and paste it into Design Code."
        default: "Design one in Infly, then it shows up here."
        }
    }

    private var symbol: String { status == .deleted ? "questionmark.square.dashed" : "square.grid.2x2" }
}

extension WidgetFamily {
    var designSize: DesignSize {
        switch self {
        case .systemMedium: .medium
        case .systemLarge, .systemExtraLarge: .large
        case .accessoryCircular: .circular
        case .accessoryRectangular: .rectangular
        case .accessoryInline: .inline
        default: .small
        }
    }
}
