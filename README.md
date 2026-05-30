# Macaveli

> A hotkey-first window manager for macOS — small, quiet, designed to disappear into muscle memory.

## Repo layout

This is a monorepo with two independent apps:

- [`macos/`](./macos) — the Swift / Xcode menubar app. See `macos/` for the
  Makefile and Xcode project.
- [`web/`](./web) — the marketing landing page (Next.js 15 + Tailwind v4).
  See [`web/README.md`](./web/README.md).

Each app builds standalone; there's no shared package layer yet.

## Vision

Macaveli is for people who don't want to think about their window manager.
Hotkeys are the product — the menubar popover is a place to **remember** the
hotkeys, not a place to operate the app. If you catch yourself clicking
around in it, we've failed.

That reframes every UI decision. Bindings are the headline because that's
what users come for. Format, quality, save folder, even quitting — all one
gear-tap away, never in front of you. Recording lives next to window
management because they share the same loop: one keystroke, no break in
flow, no context switch.

The success criterion: you open the popover the first week to learn the
hotkeys, and then maybe never again. The dock icon doesn't exist. The
menubar icon barely does. Macaveli works best when you forget you installed
it — when `⌃⌘↑` is just "how my Mac works now."

## Why it was created

macOS shipped without real window management. The native answer (Mission
Control, Stage Manager) is gesture-first and won't help you place a window
precisely. The third-party answer (Rectangle, Magnet, Spectacle) solves
"snap to halves and thirds" — but stops there. Moving or resizing an
arbitrary window still means hunting for a 4-pixel title bar or corner
with the mouse.

Linux desktops and BetterTouchTool have had the right primitive for decades:
**hold a modifier, drag anywhere on the window to move it; hold a different
modifier, drag anywhere to resize it.** That one gesture replaces ten snap
hotkeys. Macaveli brings that primitive to macOS cleanly, pairs it with
the snap actions you still want (maximize, center, halves), and includes a
hotkey-driven screen recorder so the *record* loop doesn't break the
keyboard flow either.

It exists because we kept reaching for `⌃⌘`-drag, and macOS didn't have one.

## Installation (macOS app)

* Download the [latest release on Github](https://github.com/jaequery/macaveli/releases)
* Or clone and build it yourself (see below)

## Contributing

You can either use Xcode or build from the command line. **Run all macOS
commands from `macos/`.**

### Build and run from the command line

```bash
cd macos
make run
```

### Accessibility permissions running locally

Make sure you don't have Macaveli running already. If you have 2 versions of Macaveli, only one will get
Accessibility permissions. To fix it:

* Quit all Macaveli instances
* Remove Macaveli from the System Preferences > Security & Privacy > Accessibility
* Run the app you want to test
* Enable Accessibility permissions

I'm open to PRs and requests.
