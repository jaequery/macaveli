# Macaveli

> Sweet window management and screen recording for macOS

## Repo layout

This is a monorepo with two independent apps:

- [`macos/`](./macos) — the Swift / Xcode menubar app. See `macos/` for the
  Makefile and Xcode project.
- [`web/`](./web) — the marketing landing page (Next.js 15 + Tailwind v4).
  See [`web/README.md`](./web/README.md).

Each app builds standalone; there's no shared package layer yet.

## Installation (macOS app)

* Download the [latest release on Github](https://github.com/jaequery/macaveli/releases)
* Or clone and build it yourself (see below)

## Features

* Launch at login
* Hide menubar icon
* Focus on window
* Smart resizing with quadrants
* Half-window snap shortcuts (`⌃[` / `⌃]`)
* Screen recording with hotkey toggle, MP4/GIF export

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
