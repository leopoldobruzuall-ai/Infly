import SwiftUI

/// Three short pages: what Infly is, how it works, and a starting style.
/// It takes actions instead of reading the Router: a paged TabView re-reads its host view's
/// properties without @Observable environment objects, which crashes.
struct OnboardingView: View {
    let start: (Preset) -> Void
    let finish: () -> Void

    @State private var page = 0
    private let motion = MotionPreference()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(page == 2 ? "Skip to Gallery" : "Skip", action: finish)
                    .font(.body.weight(.medium))
            }
            .padding(.horizontal, Space.l)
            .padding(.top, Space.s)

            TabView(selection: $page) {
                welcome.tag(0)
                steps.tag(1)
                starters.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: Space.l) {
                HStack(spacing: Space.s) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == page ? 22 : 7, height: 7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of 3")

                if page < 2 {
                    Button {
                        withAnimation(motion.animation()) { page += 1 }
                    } label: {
                        Text("Continue").frame(maxWidth: 320)
                    }
                    .prominentStyle()
                    .controlSize(.large)
                } else {
                    Text("Pick one to start editing. You can change everything.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 50)
                }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
            .animation(motion.animation(), value: page)
        }
        .background(AppBackdrop())
    }

    private var welcome: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                HStack(spacing: -Space.l) {
                    ForEach(Array(["frost", "golden-ridge", "prism"].enumerated()), id: \.element) { index, id in
                        if let preset = Presets.preset(id: id) {
                            DesignPreview(design: preset.template, maxPixels: 500)
                                .frame(width: 112, height: 112)
                                .rotationEffect(.degrees(Double(index - 1) * 7))
                                .offset(y: index == 1 ? -12 : 0)
                                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                                .zIndex(index == 1 ? 1 : 0)
                        }
                    }
                }
                .padding(.top, Space.xxl)
                .accessibilityHidden(true)

                VStack(spacing: Space.m) {
                    Text("Infly").font(.largeTitle.weight(.bold))
                    Text("Beautiful widgets, made yours in a minute.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Space.xl)
            .frame(maxWidth: .infinity)
        }
    }

    private var steps: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Text("How it works").font(.largeTitle.weight(.bold))
                step("sparkles", "Pick a style", "Start from a curated preset or a blank widget.")
                step("slider.horizontal.3", "Make it yours", "Change type, colors, photos and layout with a live preview.")
                step("plus.square.on.square", "Add it", "Add the Infly widget to your Home Screen or Lock Screen, then choose your design.")
            }
            .padding(Space.xl)
            .padding(.top, Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func step(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.l) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .glassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var starters: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Choose a starting style").font(.title.weight(.bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.m)], spacing: Space.m) {
                    ForEach(Presets.starterIDs.compactMap(Presets.preset(id:))) { preset in
                        Button { start(preset) } label: {
                            VStack(alignment: .leading, spacing: Space.s) {
                                DesignPreview(design: preset.template, size: .small, maxPixels: 500)
                                    .frame(height: 130)
                                Text(preset.name).font(.subheadline.weight(.semibold))
                                Text(preset.template.kind.title).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(Space.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardSurface()
                            .contentShape(.rect)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(preset.name), \(preset.template.kind.title)")
                    }
                }
            }
            .padding(Space.xl)
        }
    }

}
