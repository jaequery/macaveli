# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

Monorepo with two apps, no monorepo tooling — each app builds independently.

- `macos/` — the macOS menubar app (Swift, Xcode, Sparkle auto-updates). All
  paths in this doc that begin with `Macaveli/` or refer to `Makefile`,
  `scripts/`, etc. live under `macos/`. **Exception: `appcast.xml` lives at the
  monorepo root** — it's the committed source of truth that `generate_appcast`
  reads/rewrites; the *served* feed is a copy uploaded to the CDN (see the
  Updates section). The `make appcast`/`make release` scripts read and write the
  repo-root copy one level up from `macos/`.
- `web/` — the marketing landing page (Next.js 15, TypeScript, Tailwind v4).
  See `web/README.md`.

The remaining sections describe the macOS app; run all macOS commands from
`macos/`.

## Build & run (macOS app)

The Makefile is the canonical way to build outside of Xcode (Xcode signing is fiddly — see README). Run from `macos/`.

- `make build` — `xcodebuild -scheme Macaveli build SYMROOT=$PWD/build`, drops the app at `./build/Debug/Macaveli.app`.
- `make run` — build + open the debug app.
- `make dmg` — runs `scripts/build-dmg.sh`: archives Release, exports a Developer-ID-signed `.app`, re-signs the bundled `ffmpeg` (Xcode misses it because it's a plain Resource, not an "Embed & Sign" build-phase output), builds a DMG with a `/Applications` symlink, signs it, then notarizes + staples via `notarytool`. Outputs `build/Macaveli-<version>.dmg` plus a stable-named `build/Macaveli.dmg` for the website.
- `make publish-web` — copies `build/Macaveli.dmg` into `../web/public/Macaveli.dmg`. The landing-page Download CTAs link to `/Macaveli.dmg`, so this is the bridge from build artifact to live site.
- `make release` — `dmg` + `publish-web`.
- `make appcast <export-folder>` — runs `scripts/generate-appcast.sh`: zips the exported `.app`, runs Sparkle's `generate_appcast` (found under `~/Library/Developer/Xcode/DerivedData/Macaveli*`), signs the zip, and rewrites the appcast URL to the GitHub releases download. Copies the updated `appcast.xml` back into the repo.
- `make generate-keys` — wraps `scripts/generate-keys.sh` (Sparkle EdDSA keypair).

### One-time setup for `make dmg`

`build-dmg.sh` pre-flights both of these and fails loudly with instructions if missing.

1. Install a **Developer ID Application** cert from <https://developer.apple.com/account/resources/certificates/list> into the login keychain. The Xcode-managed "Apple Development" cert is dev-only — Gatekeeper won't accept it.
2. Create a `notarytool` keychain profile (one time): `xcrun notarytool store-credentials macaveli-notary --apple-id <email> --team-id 7BWUZV469T --password <app-specific password from appleid.apple.com>`.

Local-test escape hatch: `SKIP_NOTARIZE=1 make dmg` builds a signed-but-not-notarized DMG (Gatekeeper warns users) without needing the notary profile.

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

`UpdatesManager` wraps `SPUStandardUpdaterController`. The feed URL and public EdDSA key are baked into `Macaveli-Info.plist` (`SUFeedURL`, `SUPublicEDKey`). `SUFeedURL` points at the **CDN** (`https://macaveli.sfo3.cdn.digitaloceanspaces.com/appcast.xml`), not GitHub — so auto-updates keep working even if the repo goes private. `appcast.xml` is committed at the repo root as the source of truth and regenerated by `make appcast` after exporting a release build; `generate-appcast.sh` rewrites each enclosure to the CDN zip (`…/Macaveli.zip`), and `make release` (via `upload-appcast`) uploads the regenerated appcast + signed zip to the CDN with `no-cache` (both use stable keys and are overwritten each release, so they must not be cached as immutable). The CDN base comes from `S3_CDN_URL` in `.env`.

**If you flip the repo private:** `SUFeedURL` already points at the CDN, so do it in this order — (1) cut at least one release *while still public* so users update to a build carrying the CDN feed URL, then (2) flip private. Apps shipped before the CDN feed was introduced had `…/main/appcast.xml` (GitHub raw) baked in; once the repo is private that URL 404s and those apps can't self-heal (the feed they fetch is the dead one). They'd need a manual reinstall.

## SPM dependencies (resolved by Xcode, not Package.swift)

Declared in `Macaveli.xcodeproj/project.pbxproj`:

- `ShortcutRecorder` — global hotkey registration + recorder UI.
- `CGEventSupervisor` — low-level CGEvent tap with per-subscriber cancel semantics; used to swallow the mouse-down that triggers a drag.
- `Sparkle` — auto-updates.
- `LaunchAtLogin-Modern` — login item toggle.

## Preferences

All settings live in `UserDefaults` via plain string keys. The canonical list is `PreferenceKey` in `src/Manager/Preferences.swift` (`focusOnApp`, `showMenuBarIcon`, `useQuadrants`, `requireMouseClick`). Per-shortcut state is stored separately by `ShortcutsManager` under `"<ShortcutType>"` (archived `Shortcut`) and `"<ShortcutType>_mouseButton"`.

## Design System

Always read `DESIGN.md` (repo root) before making any visual or UI decision, in the
macOS app **and** the web landing page — they share one system. Font choices, color
tokens, spacing, layout, and aesthetic direction are defined there. North star:
"one install, your Mac is ready" (Apple-native minimalism; SF Pro + JetBrains Mono
signature; cyan→pink aurora wash for hero/first-run only). Do not deviate without
explicit user approval. In QA mode, flag any UI that doesn't match `DESIGN.md`.
