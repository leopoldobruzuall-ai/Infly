<img src="docs/icon.png" width="96" alt="Infly app icon">

# Infly

Beautiful iPhone widgets, made yours in a minute. Pick a style, customize it with a live preview, save it, then add the Infly widget to your Home Screen or Lock Screen and choose your design.

Swift, SwiftUI and WidgetKit. No accounts, analytics, network access or third-party dependencies.

![Every preset, rendered by the same view the widget uses](docs/presets.png)

## Status

| | |
|---|---|
| Xcode project (app, widget extension, unit tests) | Done |
| Typechecked against the iOS 18 API surface | Yes. App and widget have zero errors and zero warnings (see [How this was verified](#how-this-was-verified)) |
| Unit tests | 16 of 16 pass |
| Built with Xcode, run in the iOS Simulator, signed, exported as `.ipa` | **Not done.** This Mac has no Xcode and no signing identity (see [What's missing for an .ipa](#whats-missing-for-an-ipa)) |

## Requirements

- **Xcode 26 or later** for the Liquid Glass look. Xcode 16.x also builds the project; the glass code is behind `#if compiler(>=6.2)`, so older Xcodes get the material fallback.
- **iOS 18.0 or later.** iOS 18 is the earliest version that has everything Infly uses:
  - `Text(.currentDate, format:)` keeps custom clock formats live in widgets without a timeline entry every minute.
  - `AppIntentConfiguration` (iOS 17) lets each widget pick a saved design.
  - `widgetAccentedRenderingMode` (iOS 18) keeps photos right on tinted and Clear Home Screens.
  - The `Tab` API and zoom transitions are iOS 18.

  iOS 18 runs on every iPhone that iOS 17 supports (XS / XR and later).
- **iOS 26 and later** get Liquid Glass (`glassEffect`, `.glass` and `.glassProminent` button styles, a tab bar that minimizes on scroll). iOS 18 uses materials with hairline edges instead.
- iPhone only, portrait.

## Set up and run

1. Open `Config/Infly.xcconfig` and set your values:
   ```
   INFLY_BUNDLE_ID_PREFIX = com.yourname
   DEVELOPMENT_TEAM = ABCDE12345
   ```
   Every bundle ID and the App Group (`group.<prefix>.infly`) derive from these, through the entitlements and both Info.plists.
2. Open `Infly.xcodeproj` in Xcode.
3. Choose the **Infly** scheme and an iPhone simulator or device, then press Run.
4. Signing is automatic. If Xcode doesn't register the App Group for you, open **Signing & Capabilities** for both the **Infly** and **InflyWidgetsExtension** targets and add `group.<prefix>.infly` under App Groups.

To try the widget, run the app, save a design, then go to the Home Screen: touch and hold → **Edit** → **Add Widget** → **Infly**. To debug the extension itself, choose the **InflyWidgetsExtension** scheme. If Xcode didn't create one, add it with **Product → Scheme → New Scheme**.

## Tests

In Xcode, press **⌘U**. From the command line, using any installed iPhone simulator:

```bash
xcodebuild test -project Infly.xcodeproj -scheme Infly -destination 'platform=iOS Simulator,name=iPhone 17'
```

`InflyTests/InflyTests.swift` uses Swift Testing. It covers:

- Save and reload across launches, and edit in place.
- **The widget extension's reader sees what the app saved.** It uses the same `DesignStore.read(from:)` the extension calls.
- Duplicate, rename (empty names rejected) and delete.
- Repeated names get numbered.
- A photo shared by duplicates survives until no design uses it.
- A missing photo is reported, not fatal, and stored photos are downsized.
- An unreadable data file is set aside, never overwritten.
- Undo, redo and Reset to Preset.
- Countdown day math across a daylight-saving change.
- Timeline refresh dates.
- Crop math always covers the widget.
- Automatic text color picks the readable choice.
- Preset integrity.
- Widget size lookup.

Things to check by hand on a device: adding Home and Lock Screen widgets, choosing a design in **Edit Widget**, tapping a widget to open its design, deleting a design that's on the Home Screen (the widget shows "Design deleted"), picking a photo while offline, and Dark Mode, tinted and Clear Home Screens, larger text, Reduce Motion and Reduce Transparency.

## Build an .ipa

With a paid Apple Developer team set in `Config/Infly.xcconfig`:

**In Xcode:** **Product → Archive**, then **Distribute App** and choose Debugging (your registered devices), Release Testing (Ad Hoc), or App Store Connect.

**From the command line:**

```bash
xcodebuild archive -project Infly.xcodeproj -scheme Infly -destination 'generic/platform=iOS' -archivePath build/Infly.xcarchive -allowProvisioningUpdates
```

```bash
xcodebuild -exportArchive -archivePath build/Infly.xcarchive -exportOptionsPlist Config/ExportOptions.plist -exportPath build -allowProvisioningUpdates
```

`Config/ExportOptions.plist` uses `debugging`. Change `method` to `release-testing` or `app-store-connect` as needed. Never put certificates, passwords or API keys in the project; Xcode reads signing from your keychain and Apple account.

## What's missing for an .ipa

This Mac has:

- **No Xcode.** Only the Command Line Tools (Swift 6.1.2, macOS 15.5 SDK) are installed. That means no iOS SDK, no Simulator, and no `actool` to compile asset catalogs.
- **No signing identity** (`security find-identity` finds 0) and no provisioning profiles.
- **About 15 GB free.** Xcode plus an iOS Simulator runtime needs more than that.

To produce the `.ipa`, install Xcode from the App Store, sign in to your Apple Developer account in Xcode → Settings → Accounts, then follow [Build an .ipa](#build-an-ipa).

## How this was verified

Without Xcode, the code was checked with the Mac Catalyst SDK. Catalyst exposes the iOS UIKit / SwiftUI / WidgetKit / App Intents APIs.

- **Typecheck.** Both targets typecheck against `arm64-apple-ios18.0-macabi` with zero errors and zero warnings.
- **Unit tests.** The real test file ran against the real sources: 16 of 16 passed.
- **Renders.** Every preset at every size was rendered to PNG through the same `WidgetCanvas` / `DesignView` code the widget uses (the images in `docs/`).
- **Smoke runs.** The app was built as a Catalyst app and launched into every tab, every editor type and section, the add-widget guide, and first-launch onboarding: 19 paths, no crashes.

  These runs caught a real crash, now fixed. A view that hosts an `.alert`, a `.confirmationDialog` or a paged `TabView` and also reads an `@Observable` object with `@Environment` crashes when presented. So the store and router are shared instances (`DesignStore.shared`, `Router.shared`) rather than environment objects.

**Not verified here:**

- The iOS 26 Liquid Glass code (compiled out by Swift 6.1).
- Asset catalog compilation.
- App Intents metadata extraction.
- A real widget on a real Home Screen.
- Signing.

Expect to fix small issues on the first Xcode build.

## Architecture

```
Infly/            App target: SwiftUI screens
  InflyApp.swift      App, Router (tabs, editor, follow-up sheets), RootView, toast
  DesignSystem/       Spacing and radius tokens, glass and card surfaces, chips, previews, brand mark
  Features/           Discover, Library (My Widgets), Editor, Onboarding, Settings
InflyWidgets/     Widget extension: Home Screen and Lock Screen widgets, intents, timeline provider
Shared/           Compiled into both targets
  Model/              WidgetDesign (Codable), presets, palettes, collections
  Storage/            DesignStore (JSON in the App Group), PhotoFiles (ImageIO), crop math
  Rendering/          DesignView, DesignBackground, WidgetCanvas, widget sizes, timeline plan
  Samples/            Four sample photos (bundled in both targets)
InflyTests/       Swift Testing unit tests
Config/           xcconfig, entitlements, Info.plists, export options
Tools/            GenerateArt.swift draws the app icon and sample photos (swift Tools/GenerateArt.swift)
```

**One renderer.** `DesignView` draws every design: in-app previews, the Discover gallery, the editor, and the real widget. The widget disables WidgetKit's content margins and applies each design's own padding, so previews match the widget exactly. Previews are drawn at the real widget size for the device's screen class (from Apple's size table), then scaled down to fit.

**Shared data.** Designs are one JSON file in the App Group container, written atomically. The extension only reads it. Each save calls `WidgetCenter.reloadAllTimelines()`. Photos are downsized to 2048 px with ImageIO, stored as JPEG next to the JSON, and removed only when no design references them. The widget decodes photos at just the size it needs, so it stays well inside the extension's memory limit.

**Choosing a design.** The Home Screen and Lock Screen widgets each have an App Intent with a design parameter. Their queries list only designs made for that placement, newest first. An unconfigured widget shows the most recent design.

**Refreshing.** Times use `Text(.currentDate, format:)`, which iOS redraws on its own. Timelines add entries only where content changes: midnight, plus each midnight and the event moment for countdowns. Timelines reload at the end.

**Liquid Glass, used sparingly.** On iOS 26, glass is reserved for floating controls: the editor's size, appearance and history controls, onboarding buttons, and toasts. Tab bars, toolbars and sheets adopt it automatically. Content cards use frosted material. With Reduce Transparency or the in-app Solid Panels setting, both become opaque.

**Accessibility.** Supported:

- Dynamic Type: semantic fonts, and a one-column grid at accessibility sizes.
- VoiceOver labels and custom actions (Rename, Duplicate, Delete) on cards.
- Reduce Motion: from iOS, or Infly's own switch. Turns off zoom transitions and animations.
- Reduce Transparency.
- Increase Contrast: stronger card edges.
- Haptics can be turned off.

## Features

- **Discover.** Four featured collections and 23 original presets, filtered by Minimal, Glass, Photography, Productivity and Color. Search, type and size filters. Every card is a true preview; tapping one zooms into the editor.
- **My Widgets.** Newest-edited first. Type chips and a size filter. Edit, rename, duplicate and delete, with confirmation for deletes. An empty state that offers "Create your first widget".
- **Editor.** Large live preview with a size picker (Home and Lock Screen), a Light/Dark preview for adaptive designs, and undo/redo. Content / Style / Layout sections, one-tap palettes, and Reset to Preset (keeps your words, photo and dates). Cancel asks before discarding changes.
- **Widget types:**
  - **Clock:** Classic, Stacked, Editorial, Minimal and Day progress layouts, with any time zone and a label.
  - **Photo:** crop by dragging and pinching, or with sliders; caption, date, shade and filters.
  - **Text and quote:** Plain, Quote, Note and Headline.
  - **Countdown:** Number, Ring and Sentence layouts, an optional exact time, and a symbol.

  Any widget can use a solid, gradient, aurora or photo background.
- **Lock Screen.** Circular, rectangular and inline versions of clock, countdown and text widgets. Photos aren't offered there because iOS tints the Lock Screen to one color.
- **Onboarding.** Three short pages, a starting style, a guided first edit, and step-by-step add-to-screen instructions after the first save.
- **Settings.** Theme, haptics, solid panels, reduce motion, how to add widgets, refresh widgets, privacy, and "Show Welcome Again".

## Known limitations

- iOS has no API for widget sizes, so previews use Apple's published table and pick the nearest screen class. Newer devices may differ by a few points.
- Widgets can't blur the wallpaper. Glass-style presets suggest depth with gradients, a sheen and a fine edge. On iOS 26, the Clear Home Screen look makes every widget real glass, and Infly's widgets adapt to it.
- The Lock Screen ignores colors and backgrounds, so the editor hides those controls for Lock Screen sizes.
- Clock times update through the system and can lag by a few seconds. Seconds can't be shown.
- App Groups need a signing team that can register them. Without the App Group, the app still works, but widgets show "Open Infly" and Settings shows a warning.
- English only, iPhone only, portrait only.
- Photos stored only in iCloud may fail to load offline. Infly then explains and asks for another photo.

## Future work

These were checked against the platform but not built:

- **Calendar "Up Next".** Needs EventKit full access (`NSCalendarsFullAccessUsageDescription`), requested only when that widget is created.
- **Battery.** `UIDevice` battery level is readable in the extension, but the widget refresh budget makes the value stale between reloads.
- **Weather.** Needs WeatherKit, which requires a paid membership and a capability, plus network and location permission. That conflicts with Infly's offline, on-device design, so it's left out.
- **Interactive widgets.** For example, "next quote" with App Intent buttons (iOS 17+).
- An Icon Composer `.icon` for a layered Liquid Glass app icon, iPad layouts, localization, and photo shuffles.
