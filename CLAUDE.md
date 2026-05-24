# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

Monorepo with two apps, no monorepo tooling — each app builds independently.

- `macos/` — the macOS menubar app (Swift, Xcode, Sparkle auto-updates). All
  paths in this doc that begin with `Macaveli/` or refer to `Makefile`,
  `appcast.xml`, `scripts/`, etc. live under `macos/`.
- `web/` — the marketing landing page (Next.js 15, TypeScript, Tailwind v4).
  See `web/README.md`.

The remaining sections describe the macOS app; run all macOS commands from
`macos/`.

## Build & run (macOS app)

The Makefile is the canonical way to build outside of Xcode (Xcode signing is fiddly — see README). Run from `macos/`.

- `make build` — `xcodebuild -scheme Macaveli build SYMROOT=$PWD/build`, drops the app at `./build/Debug/Macaveli.app`.
- `make run` — build + open the debug app.
- `make appcast <export-folder>` — runs `scripts/generate-appcast.sh`: zips the exported `.app`, runs Sparkle's `generate_appcast` (found under `~/Library/Developer/Xcode/DerivedData/Macaveli*`), signs the zip, and rewrites the appcast URL to the GitHub releases download. Copies the updated `appcast.xml` back into the repo.
- `make generate-keys` — wraps `scripts/generate-keys.sh` (Sparkle EdDSA keypair).

There is no test target.

### Accessibility-permissions gotcha when iterating locally

macOS keys accessibility grants by bundle id + binary signature. Running multiple builds (Xcode, `make`, an installed release) confuses System Settings → Privacy & Security → Accessibility — only one will keep the permission. If shortcuts silently stop working after a rebuild: quit every Macaveli instance, delete it from the Accessibility list, relaunch the build under test, re-grant.

## Architecture

macOS menu-bar app (SwiftUI `MenuBarExtra` in `Macaveli/src/App.swift`, with an `NSApplicationDelegateAdaptor` for lifecycle). No main window — UI lives in the menubar popover.

### Control flow when a shortcut fires

The interesting code path is shortcut → mouse event interception → AX window manipulation. Three singletons cooperate:

1. **`ShortcutsManager.shared`** (`src/Manager/ShortcutsManager.swift`) — loads `UserShortcut`s from `UserDefaults` (one per `ShortcutType`: `.move`, `.resize`). For each shortcut it picks one of two registration paths based on whether the shortcut is modifier-only:
   - **Normal shortcut** (has a non-modifier key): registered via ShortcutRecorder's `GlobalShortcutMonitor` with separate `.down` / `.up` `ShortcutAction`s.
   - **Modifier-only** (e.g. just `⌃⌥`): ShortcutRecorder doesn't deliver key-up for these, so it falls back to `NSEvent.addGlobalMonitorForEvents` + `addLocalMonitorForEvents` watching `.flagsChanged`. `handleFlagsChanged` force-stops tracking on every flag change, then starts again if the current modifier mask matches.
2. **`CGEventSupervisor`** (SPM dep) — when a `UserShortcut` has a `mouseButton` other than `.none`, `startTracking` subscribes to `.leftMouseDown`/`.rightMouseDown` (and `…Up`) CGEvents, **cancels** them (so the host app never sees the click), and uses them as the start/stop trigger for `MouseTracker`. When `mouseButton == .none`, `MouseTracker` starts immediately on shortcut-down.
3. **`MouseTracker.shared`** (`src/Manager/MouseTracker.swift`) — once started, calls `WindowManager.getCurrentWindow()` once to snapshot the target window, then installs an `NSEvent.addGlobalMonitorForEvents` for the appropriate drag/move event type and updates the window's AX `kAXPositionAttribute` / `kAXSizeAttribute` on each callback. A 4 s `trackingTimer` auto-stops tracking as a safety net.

`AppDelegate.applicationDidFinishLaunching` touches `ShortcutsManager.shared` immediately so shortcuts work before the menubar UI is ever opened.

### Window targeting

`WindowManager.getCurrentWindow()` (`src/Manager/WindowManager.swift`) finds the window under the cursor in two stages:

1. Primary: `AXUIElementCopyElementAtPosition` on the system-wide AX element, then walk parents until the element with role `kAXWindowRole` is found.
2. Fallback (when AX hit-testing fails): enumerate `CGWindowListCopyWindowInfo` sorted by layer, find the first window whose bounds contain the cursor, then pull its `AXUIElement` via the owning PID.

Windows belonging to Macaveli itself are skipped. Windows from apps in `IGNORE_APP_BUNDLE_ID` (`src/Constants.swift` — CleanShotX, HazeOver, the notification center) are skipped at both the targeting step and the `MouseTracker.shouldIgnore` step. Add new opt-outs here.

### Quadrant resize

When the `useQuadrants` preference is on, `MouseTracker.prepareTracking` snapshots which 3×3 cell of the window the cursor started in (`determineQuadrant`). `resizeWindowBasedOnMouseLocation` then dispatches per-cell logic: corners pin the opposite corner, edges resize one axis, **center resizes symmetrically from the middle**. Note the y-axis flip — AX uses top-left origin while `NSEvent.mouseLocation` uses bottom-left, hence `convertYCoordinateBecauseTheAreTwoFuckingCoordinateSystems` in `WindowManager`.

### Updates (Sparkle)

`UpdatesManager` wraps `SPUStandardUpdaterController`. The feed URL and public EdDSA key are baked into `Macaveli-Info.plist` (`SUFeedURL`, `SUPublicEDKey`). `appcast.xml` is committed in the repo root and regenerated by `make appcast` after exporting a release build from Xcode — the script rewrites the download URL to point at the GitHub releases download for `jaequery/Macaveli`.

## SPM dependencies (resolved by Xcode, not Package.swift)

Declared in `Macaveli.xcodeproj/project.pbxproj`:

- `ShortcutRecorder` — global hotkey registration + recorder UI.
- `CGEventSupervisor` — low-level CGEvent tap with per-subscriber cancel semantics; used to swallow the mouse-down that triggers a drag.
- `Sparkle` — auto-updates.
- `LaunchAtLogin-Modern` — login item toggle.

## Preferences

All settings live in `UserDefaults` via plain string keys. The canonical list is `PreferenceKey` in `src/Manager/Preferences.swift` (`focusOnApp`, `showMenuBarIcon`, `useQuadrants`, `requireMouseClick`). Per-shortcut state is stored separately by `ShortcutsManager` under `"<ShortcutType>"` (archived `Shortcut`) and `"<ShortcutType>_mouseButton"`.
