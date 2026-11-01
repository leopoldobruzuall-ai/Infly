import SwiftUI
import UIKit

@main
struct InflyApp: App {
    @AppStorage(Prefs.appearance) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

struct EditorRequest: Identifiable {
    let id = UUID()
    let design: WidgetDesign
    let isNew: Bool
    var sourceID: String?
    /// First-run editing shows a short hint.
    var guided = false
}

/// App-wide navigation: the selected tab, the editor, and what to present after a sheet closes.
@MainActor @Observable
final class Router {
    /// Shared rather than injected with .environment: views that host an alert, a confirmation
    /// dialog or a paged TabView lose @Observable environment objects when presented, and crash.
    static let shared = Router()

    enum Tab: Hashable { case discover, library, settings }

    /// Something to present once the current full-screen view finishes dismissing.
    enum FollowUp {
        case editor(EditorRequest)
        case guide(WidgetDesign)
    }

    var tab = Tab.discover
    var editor: EditorRequest?
    var guideDesign: WidgetDesign?
    var followUp: FollowUp?
    var toast: String?
    var saveCount = 0

    func edit(_ design: WidgetDesign, isNew: Bool, from sourceID: String? = nil) {
        editor = EditorRequest(design: design, isNew: isNew, sourceID: sourceID)
    }

    /// For widgets that can't read Infly's storage: paste this into Edit Widget → Design Code.
    func copyWidgetCode(of design: WidgetDesign) {
        UIPasteboard.general.string = design.widgetCode
        toast = "Widget code copied"
    }

    func runFollowUp() {
        switch followUp {
        case .editor(let request): editor = request
        case .guide(let design): guideDesign = design
        case nil: break
        }
        followUp = nil
    }

    /// infly://design/<id> opens that design; anything else lands in My Widgets.
    func open(_ url: URL, store: DesignStore) {
        guard url.scheme == "infly", editor == nil else { return }
        tab = .library
        if url.host() == "design", let id = UUID(uuidString: url.lastPathComponent), let design = store.designs.first(where: { $0.id == id }) {
            edit(design, isNew: false)
        }
    }
}

struct RootView: View {
    private var store: DesignStore { .shared }
    private var router: Router { .shared }
    @AppStorage(Prefs.hasOnboarded) private var hasOnboarded = false
    @Namespace private var zoom
    private let motion = MotionPreference()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Discover", systemImage: "sparkles", value: Router.Tab.discover) {
                DiscoverView()
            }
            Tab("My Widgets", systemImage: "square.grid.2x2", value: Router.Tab.library) {
                LibraryView()
            }
            Tab("Settings", systemImage: "gearshape", value: Router.Tab.settings) {
                SettingsView()
            }
        }
        .minimizingTabBar()
        .environment(\.zoomNamespace, motion.reduced ? nil : zoom)
        .fullScreenCover(item: $router.editor, onDismiss: editorClosed) { request in
            EditorView(request: request)
                .zoomTransition(sourceID: motion.reduced ? nil : request.sourceID, in: zoom)
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 }), onDismiss: router.runFollowUp) {
            OnboardingView { preset in
                var design = preset.makeDesign()
                design.size = .small
                router.followUp = .editor(EditorRequest(design: design, isNew: true, guided: true))
                hasOnboarded = true
            } finish: {
                router.tab = .discover
                hasOnboarded = true
            }
        }
        .sheet(item: $router.guideDesign) { design in
            NavigationStack { AddWidgetGuide(design: design) }
        }
        .overlay(alignment: .bottom) { ToastView(message: $router.toast) }
        .haptic(.success, trigger: router.saveCount)
        .alert("Something Went Wrong", isPresented: Binding(get: { store.problem != nil }, set: { if !$0 { store.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.problem ?? "")
        }
        .onOpenURL { router.open($0, store: store) }
        .task { store.removeOrphanedImages() }
    }

    private func editorClosed() {
        // Photos picked but never saved, or replaced, are no longer referenced.
        store.removeOrphanedImages()
        router.runFollowUp()
    }
}

/// A brief confirmation that floats above the tab bar and is announced to VoiceOver.
struct ToastView: View {
    @Binding var message: String?
    private let motion = MotionPreference()

    var body: some View {
        ZStack {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassSurface(in: Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        AccessibilityNotification.Announcement(message).post()
                        try? await Task.sleep(for: .seconds(2.2))
                        self.message = nil
                    }
            }
        }
        .padding(.bottom, 72)
        .animation(motion.animation(.smooth), value: message)
    }
}
