<!-- supabuild:plan:start -->
## 🤖 Supabuild plan
**Status:** planning · branch `supabuild/paste-clipboard-20260524-084843` · target `none`
**Worktree:** `/Users/jaequery/Projects/macaveli.supabuild-paste-clipboard-20260524-084843`
**Updated:** 2026-05-24T08:48:43Z

### Goal
Add a clipboard history manager ("Paste") to Macaveli — invoked by ⌃⌘P, showing recent text + image clipboard items in a floating panel; selecting an item pastes it into the focused app.

### Acceptance criteria
- [ ] New `ShortcutType.paste` exists, defaults to `⌃⌘P`, is **user-rebindable** in the existing shortcut UI (Cheatsheet → settings strip), and appears as a new section in `CheatsheetView`.
- [ ] Pressing the hotkey toggles a floating, focused, key-accepting panel (`PasteWindow`) listing recent clipboard items newest-first.
- [ ] `PasteManager` captures **text (plain + RTF)** and **images (PNG/TIFF)** copied from any app into NSPasteboard. File URLs and other types are ignored (out of scope).
- [ ] Identical-content consecutive copies are de-duplicated (the latest re-occurrence bumps the existing item to top, no growth).
- [ ] History persists across app restarts via Application Support (`~/Library/Application Support/Macaveli/PasteHistory/`).
- [ ] History cap defaults to **100 items**, user-configurable in the Paste settings strip (range 25–500). Oldest items evict when cap is exceeded; image blobs on disk are cleaned up.
- [ ] Items copied while holding the `org.nspasteboard.ConcealedType` privacy marker (used by password managers) are **never captured**.
- [ ] Selecting an item (Enter or click) copies it back to `NSPasteboard.general`, dismisses the panel, restores focus to the previously-focused app, and dispatches `⌘V` so the item lands in that app.
- [ ] Keyboard navigation works: ↑/↓ moves selection, Enter pastes, Esc closes, ⌘1–⌘9 quick-paste, ⌘F focuses the search box, ⌘⌫ deletes the highlighted item, ⌘⇧⌫ clears all history.
- [ ] Search input filters items by text content (case-insensitive substring); image items show their MIME + size and match if "image" is typed.
- [ ] Panel is keyboard-accessible (focus ring on selection), respects light/dark mode, and follows the existing Cheatsheet visual style (rounded corners, divider, semibold uppercase labels at 10pt tracking).

### Out of scope
- File-URL clipboard items (drag-copied Finder items).
- Pinning / favorites.
- Snippet/template management ("Pastebot"-style smart text actions).
- iCloud sync across devices.
- Rich-text re-rendering inside the panel (we show plain-text preview even for RTF; RTF data is preserved and pasted faithfully).
- Custom paste-without-formatting hotkey (could be added later).
- Multi-monitor positioning preferences — panel always opens centered on the active screen.

### Architecture

**New files**
- `macos/Macaveli/src/Model/PasteboardItem.swift` — value type representing a single clipboard entry: `id: UUID`, `kind: Kind` (`.text(String, rtf: Data?)` / `.image(filename: String)`), `preview: String`, `byteSize: Int`, `createdAt: Date`. `Codable` for persistence.
- `macos/Macaveli/src/Manager/PasteManager.swift` — singleton `final class PasteManager: ObservableObject`. Responsibilities:
  - Poll `NSPasteboard.general.changeCount` on a 0.5s `Timer` on main runloop. On change, capture (skip if `ConcealedType` flavor present).
  - Maintain `@Published var items: [PasteboardItem]` (newest first).
  - De-dupe: if new content equals `items.first`, no-op (or bump timestamp); if matches an older item, move-to-front.
  - Evict oldest beyond `historyCap` (UserDefault, default 100). Delete associated image files on eviction.
  - `togglePanel()`, `showPanel()`, `hidePanel()` — manage `PasteWindow` lifecycle.
  - `activate(_ item:)` — write item back to `NSPasteboard.general`, hide panel, activate previous app, dispatch synthetic `⌘V` via `CGEvent`.
  - `delete(_ item:)`, `clearAll()` — mutate store + persist.
  - `saveManifest()` (debounced) and `loadManifest()` at init.
- `macos/Macaveli/src/View/PasteWindow.swift` — `NSPanel` subclass: borderless, `.nonactivatingPanel` style, `.floating` level, hosts `PasteView`. Helper `PasteWindow.makeWindow(rootView:)` mirroring `AnnotatorWindow`.
- `macos/Macaveli/src/View/PasteView.swift` — SwiftUI: search bar at top, scrollable list of `PasteRow` cells (preview, type icon, relative timestamp), keyboard-handling via `.onKeyPress` (macOS 14+) or `NSEvent.localEventMonitor` fallback. `@ObservedObject var manager = PasteManager.shared`.

**Modified files**
- `macos/Macaveli/src/Manager/ShortcutsManager.swift` — add `.paste = "Paste"` to `ShortcutType`; `.paste` returns `false` from `isMouseDriven`; add `seedPasteShortcutIfNeeded()` defaulting to `⌃⌘P` (`.ansiP` + `[.command, .control]`); add `case .paste: PasteManager.shared.togglePanel()` to `addOneShotAction` switch.
- `macos/Macaveli/src/Manager/Preferences.swift` — add `case pasteHistorySize = "pasteHistorySize"` to `PreferenceKey`. (Loaders for the existing `loadBool` helper are not needed — we'll use `UserDefaults.standard.integer(forKey:)` directly with a 100 default.)
- `macos/Macaveli/src/View/CheatsheetView.swift` — add a new `.paste` `CheatSectionID`, a `pasteRows` array (one row: "Show clipboard history"), a `PasteSettingsStrip` containing a stepper/slider for `pasteHistorySize` and a "Clear history" button. Wire the new section in the `VStack` between `.annotate` and the footer.
- `macos/Macaveli/src/AppDelegate.swift` — touch `PasteManager.shared` in `applicationDidFinishLaunching` so the clipboard monitor begins before any UI interaction.

**Data**
- Storage location: `~/Library/Application Support/Macaveli/PasteHistory/`.
  - `manifest.json` — array of `PasteboardItem` (UUID, kind, preview, byteSize, createdAt, image filename if any).
  - `images/<uuid>.png` — image payloads (PNG; TIFF re-encoded to PNG on capture).
- No DB. Persistence is "best-effort JSON" — on read failure, start with empty history and log; do not crash.

**Surfaces**
- Routes: n/a · Jobs: n/a · Events: NSPasteboard polling · Env: n/a
- New global hotkey: ⌃⌘P (rebindable).
- New floating panel window.

### Risks & mitigations
- **Hotkey conflicts** — ⌃⌘P could clash with another app. → User can rebind via the same Cheatsheet UI as every other Macaveli shortcut; document this in the row description.
- **Polling overhead** — 0.5s timer on every clipboard change. → Cheap operation (just `changeCount` read); guard against expensive image decoding by deferring `NSImage` decode until the user opens the panel (store raw `Data` for image payloads).
- **Image storage growth** — large screenshots accumulate. → Re-encode to PNG (smaller than TIFF), cap history items, evict oldest with file cleanup. Add an "image bytes used" line under the size stepper.
- **Sandbox / entitlements** — currently the entitlements file is empty (no sandbox). Application Support writes work without extra entitlements. → No entitlement change required.
- **Password manager leakage** — capturing 1Password / Bitwarden secrets is the canonical clipboard-manager footgun. → Honor `org.nspasteboard.ConcealedType` flavor (de-facto standard for opt-out: <http://nspasteboard.org>). Document the support in code.
- **Synthetic ⌘V into apps without paste support** — could be a no-op surprise. → That's the same UX users already have with system clipboard; not a regression. Log a debug message if ⌘V fails to post.
- **Focus restoration** — the panel must give focus back to the prior app for ⌘V to land in the right place. → Capture `NSWorkspace.shared.frontmostApplication` *before* showing the panel; restore via `activate(options:)` before posting the CGEvent.
- **Concurrent persistence writes** — burst of copies can hammer disk. → Debounce `saveManifest()` to 1s on a serial queue.

### Verification map
| # | Criterion | Proof |
|---|-----------|-------|
| 1 | `.paste` ShortcutType + default ⌃⌘P | `Code Review` confirms enum + seed; `Build` succeeds. |
| 2 | Hotkey toggles panel | Manual: build + launch + press ⌃⌘P — code reviewer traces dispatch path. |
| 3 | Text + image capture | `PasteManager` unit logic reviewed (manual capture cases enumerated in `capture(_ pb:)`). |
| 4 | De-dup | Logic reviewed: matching `items.first` on `kind` + content hash. |
| 5 | Persistence | `manifest.json` is read at init, written on every mutation (debounced); restart-survival traced in code review. |
| 6 | Configurable history size | `PreferenceKey.pasteHistorySize` defined; `PasteSettingsStrip` stepper bound to UserDefaults; eviction uses live value. |
| 7 | Concealed-type opt-out | Explicit `pb.types.contains("org.nspasteboard.ConcealedType")` check in `capture(_:)`. |
| 8 | Paste action | `activate(_ item:)` traced: write → hide → restore focus → CGEvent ⌘V. |
| 9 | Keyboard nav | `PasteView` key handlers reviewed for ↑/↓/Enter/Esc/⌘1-9/⌘F/⌘⌫/⌘⇧⌫. |
| 10 | Search filter | Filter function reviewed; case-insensitive substring on `preview`. |
| 11 | Design system | UI Designer ensures Cheatsheet visual conventions: 10pt uppercase tracking labels, 14pt body, rounded corners, accent color treatment. |

### Rollback
Revert is safe. No migrations, no destructive UserDefaults changes. To fully clean up, user can delete `~/Library/Application Support/Macaveli/PasteHistory/`. Branch `supabuild/paste-clipboard-20260524-084843` carries the work; rolling back is `git worktree remove` + `git branch -D`.

### Round log
- (filled in as rounds run)
<!-- supabuild:plan:end -->
