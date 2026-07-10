// Release history for the public changelog page.
//
// v0.25.4 is the authoritative current release (matches version.json and the
// `release v0.25.4` tag commit). Earlier entries are reconstructed from git
// history grouped by date — their exact version boundaries are inferred, so
// verify/adjust version numbers here when cutting future releases.

export type ChangeType = "feature" | "fix" | "improvement";

export interface Change {
  type: ChangeType;
  text: string;
}

export interface Release {
  version: string;
  /** ISO date, yyyy-mm-dd. */
  date: string;
  summary?: string;
  changes: Change[];
}

// Newest first.
export const releases: Release[] = [
  {
    version: "0.27.2",
    date: "2026-07-10",
    summary: "Macaveli gets its crown — a new menubar icon you can spot at a glance.",
    changes: [
      { type: "improvement", text: "New menubar icon: the M-crown. The Macaveli M is redrawn as a solid crown silhouette, so it no longer blends in with other letter-shaped menubar icons — one glance and you know where your window hotkeys live." },
    ],
  },
  {
    version: "0.27.1",
    date: "2026-06-19",
    summary: "Fixes the \"Permissions Required\" dead-end when you launch straight from the disk image.",
    changes: [
      { type: "fix", text: "If you opened Macaveli right from the DMG or your Downloads folder, macOS could keep showing \"Permissions Required\" even after you granted access — because it was running from a temporary copy your grant didn't stick to. The prompt now spots this and offers a one-click \"Move to Applications & Relaunch\" to fix it for good, plus a reliable Quit & Relaunch to apply a fresh Screen Recording grant." },
    ],
  },
  {
    version: "0.27.0",
    date: "2026-06-19",
    summary: "Spot the right screenshot at a glance, and jump to your save folders faster.",
    changes: [
      { type: "feature", text: "Clipboard history now shows a thumbnail preview for copied images, so two screenshots are no longer indistinguishable — you can tell them apart without pasting first." },
      { type: "improvement", text: "Save-folder paths are now clickable: tap the path to open the folder in Finder. The screen-record section gained the same shortcut, replacing its separate Browse button." },
    ],
  },
  {
    version: "0.26.0",
    date: "2026-06-10",
    summary: "More control over staying awake, and a tidier Tweaks tab.",
    changes: [
      { type: "feature", text: "Never Sleep now has a lid-closed option that works on battery, for finishing a download or render with the Mac in hand. It's the one mode nothing turns off for you, so it asks you to confirm — switch it off when you're done." },
      { type: "improvement", text: "The plugged-in lid-closed mode is clearer about what it does: it stays awake only while plugged in and turns itself off the moment you unplug, so it can't drain in a bag." },
      { type: "improvement", text: "Redesigned the Tweaks tab with System Settings–style grouped cards, and added hover cards explaining each Never Sleep mode and when to use it." },
      { type: "improvement", text: "The \"log out to take full effect\" banner in Keyboard settings now appears only when you've actually changed something this session, instead of always." },
    ],
  },
  {
    version: "0.25.11",
    date: "2026-05-31",
    changes: [
      { type: "fix", text: "Fixed the Log Out button in Keyboard settings — it now reliably starts logout, and if macOS blocks it, points you to the  menu instead of doing nothing." },
    ],
  },
  {
    version: "0.25.10",
    date: "2026-05-31",
    summary: "Dial in your keyboard's repeat speed.",
    changes: [
      { type: "feature", text: "New Keyboard tweak: set how fast keys repeat and how long to wait before they start — faster than macOS's own sliders allow, with a one-tap Fast preset and a Reset to default. Takes full effect after you next log out." },
    ],
  },
  {
    version: "0.25.9",
    date: "2026-05-31",
    summary: "Lid-closed Never Sleep that can't drain your battery in a bag.",
    changes: [
      { type: "improvement", text: 'The "even when the lid is closed" level now only turns on while your Mac is plugged in.' },
      { type: "feature", text: "If you unplug while it's on, Macaveli now switches it back off for you automatically — so it can never keep the Mac awake and draining inside a closed bag." },
    ],
  },
  {
    version: "0.25.8",
    date: "2026-05-31",
    changes: [
      { type: "improvement", text: "Never Sleep now keeps the screen itself on, on battery as well as power — not just preventing system sleep." },
    ],
  },
  {
    version: "0.25.7",
    date: "2026-05-30",
    changes: [
      { type: "feature", text: "Add your own labels to clipboard items so they're easier to find." },
      { type: "improvement", text: 'Renamed "Shortcuts" to "Hotkeys" throughout the app for clarity.' },
      { type: "improvement", text: "The app version now shows next to the name in the menu header." },
      { type: "fix", text: "Stopped the clipboard panel from jumping around with a scroll loop." },
    ],
  },
  {
    version: "0.25.4",
    date: "2026-05-28",
    changes: [
      { type: "improvement", text: "Removed the keyboard repeat-rate tweak — it changed a system-wide setting that only applied after logout, so it never reliably worked." },
    ],
  },
  {
    version: "0.25.3",
    date: "2026-05-28",
    summary: "Never Sleep — keep your Mac awake on your terms.",
    changes: [
      { type: "feature", text: "New Never Sleep control with three levels: off, awake while the lid is open, or awake even when the lid is closed to keep an external display on." },
      { type: "improvement", text: "The lid-open level needs no password and switches off automatically when you quit Macaveli; the lid-closed level asks you to confirm before changing a system-wide setting." },
      { type: "fix", text: "More reliable switching, clearer error messages, and sturdier reading of the system sleep state." },
    ],
  },
  {
    version: "0.25.2",
    date: "2026-05-27",
    summary: "Faster, calmer keyboard handling and a tidier menu.",
    changes: [
      { type: "improvement", text: "Karabiner-style key repeat replaces the old trigger delay for snappier, more predictable shortcuts." },
      { type: "improvement", text: "The menu popover is now split into Shortcuts and Tweaks tabs." },
      { type: "improvement", text: "Modernized the top-right menu trigger with a ghost-button affordance." },
      { type: "feature", text: "Added a configurable key-press wait interval." },
    ],
  },
  {
    version: "0.25.1",
    date: "2026-05-26",
    changes: [
      { type: "feature", text: "External displays now stay awake when the laptop lid closes." },
      { type: "feature", text: "Save annotated screenshots straight to disk from the Annotate window." },
      { type: "fix", text: "Move and resize now work on the Annotate window." },
      { type: "fix", text: 'Aligned the "Check for Updates" row with the rest of the menu.' },
    ],
  },
  {
    version: "0.25.0",
    date: "2026-05-25",
    summary: "Clipboard history and recording arrive.",
    changes: [
      { type: "feature", text: "Clipboard history — a searchable, local-only record of everything you copy." },
      { type: "feature", text: "Screenshot-to-clipboard capture with a confirmation toast." },
      { type: "feature", text: "Draggable camera overlay for screen recordings." },
    ],
  },
  {
    version: "0.24.0",
    date: "2026-05-24",
    summary: "Annotation suite and a signed, notarized release pipeline.",
    changes: [
      { type: "feature", text: "Annotation tools — select, move, resize, rotate, and delete placed annotations, with a tool-aware cursor." },
      { type: "feature", text: "Signed + notarized DMG pipeline with self-hosted downloads." },
      { type: "feature", text: "Launch at Login is enabled by default on first run." },
      { type: "improvement", text: "Recordings now capture system audio only — microphone capture removed." },
      { type: "fix", text: "Maximize and center now work on Slack and other Electron apps." },
      { type: "fix", text: "Register Macaveli with macOS before opening System Settings so permission prompts behave." },
    ],
  },
];
