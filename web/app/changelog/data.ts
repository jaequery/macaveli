// Release history for the public changelog page.
//
// v0.25.2 is the authoritative current release (matches version.json and the
// `release v0.25.2` tag commit). Earlier entries are reconstructed from git
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
