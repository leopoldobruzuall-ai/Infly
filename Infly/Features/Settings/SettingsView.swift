import SwiftUI
import WidgetKit

struct SettingsView: View {
    private var store: DesignStore { .shared }
    private var router: Router { .shared }
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.solidPanels) private var solidPanels = false
    @AppStorage(Prefs.reduceMotion) private var reduceMotion = false
    @AppStorage(Prefs.hasOnboarded) private var hasOnboarded = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Haptics", isOn: $haptics)
                }

                Section {
                    Toggle("Solid Panels", isOn: $solidPanels)
                    Toggle("Reduce Motion", isOn: $reduceMotion)
                } header: {
                    Text("Accessibility")
                } footer: {
                    Text("Solid Panels swaps glass for opaque backgrounds. Infly also follows Reduce Transparency, Reduce Motion, Increase Contrast and your text size from iOS Settings.")
                }

                Section {
                    NavigationLink {
                        AddWidgetGuide()
                    } label: {
                        Label("How to Add Widgets", systemImage: "plus.square.on.square")
                    }
                    Button {
                        WidgetCenter.shared.reloadAllTimelines()
                        router.toast = "Widgets refreshed"
                    } label: {
                        Label("Refresh Widgets", systemImage: "arrow.clockwise")
                    }
                    LabeledContent("Saved Designs", value: store.designs.count, format: .number)
                } header: {
                    Text("Widgets")
                } footer: {
                    if !store.isShared {
                        Text("Widgets can't see your designs because this build has no App Group. See the README to set one up.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Privacy") {
                    InfoRow(symbol: "iphone", title: "Stays on this iPhone", detail: "Designs and photos never leave your device. No accounts, analytics, ads or network access.")
                    InfoRow(symbol: "hand.raised", title: "No permissions needed", detail: "The system photo picker shares only the photos you choose. Infly can't see the rest of your library.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.version)
                    Button("Show Welcome Again") { hasOnboarded = false }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
            .navigationTitle("Settings")
        }
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol).foregroundStyle(.tint).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Step-by-step instructions for the system widget flow. After a first save it shows the new design on top.
struct AddWidgetGuide: View {
    var design: WidgetDesign?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let design {
                Section {
                    VStack(spacing: Space.m) {
                        DesignPreview(design: design).frame(height: design.size == .large ? 260 : 160)
                        Text("“\(design.name)” is saved. Here's how to put it on your \(design.size.placement).")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Space.s)
                    .frame(maxWidth: .infinity)
                }
            }
            if design?.size.isLockScreen != true {
                Section {
                    step(1, "Touch and hold an empty area of your Home Screen until the apps jiggle.")
                    step(2, "Tap Edit in the top-left corner, then Add Widget.")
                    step(3, "Search for Infly, swipe to the size you want, then tap Add Widget.")
                    step(4, "Tap the new widget, or touch and hold it and choose Edit Widget. Under Design, pick yours.")
                } header: {
                    Label("Home Screen", systemImage: "apps.iphone")
                }
            }
            if design.map({ $0.size.isLockScreen }) ?? true {
                Section {
                    step(1, "Touch and hold your Lock Screen, then tap Customize and choose Lock Screen.")
                    step(2, "Tap the widget area below the time.")
                    step(3, "Choose Infly Lock Screen, then tap the widget you added and pick your design.")
                    step(4, "Tap Done.")
                } header: {
                    Label("Lock Screen", systemImage: "lock.iphone")
                }
            }
            Section("Good to Know") {
                Text("Tap any Infly widget to open its design here. Your edits reach your widgets within moments of saving.")
                Text("Each widget can show any design of its kind, so you can swap designs without removing the widget.")
            }
        }
        .navigationTitle(design == nil ? "Add Widgets" : "Your Widget Is Ready")
        .navigationBarTitleDisplayMode(design == nil ? .large : .inline)
        .toolbar {
            if design != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentColor, in: Circle())
            Text(text)
        }
        .accessibilityElement(children: .combine)
    }
}
