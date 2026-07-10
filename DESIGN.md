# Design System — Macaveli

> Created by `/design-consultation` on 2026-05-25. Read this before any visual or
> UI work, in the macOS app **and** the web landing page. They share one system.

## North Star
**One install, your Mac is ready.** Every design decision serves this: the product
should feel like it shipped *with* macOS — calm, confident, effortless. If a choice
adds noise or fights the platform, cut it.

## Product Context
- **What this is:** An opinionated, zero-config macOS menubar utility bundle —
  window management (alt-drag move/resize), screenshots + annotation, clipboard
  history, screen recording — in one free app.
- **Who it's for:** People setting up a fresh Mac, especially newcomers and
  web / vibe-coding developers who don't want to research and install twelve tools.
- **Space:** macOS productivity utilities. Real competitor: Raycast (broad, configurable);
  Macaveli is narrow, pre-configured, opinionated.
- **Project type:** HYBRID — native macOS app (menubar popover/cheatsheet, first-run
  welcome window) + marketing landing site (`web/`, Next.js).

## Aesthetic Direction
- **Direction:** Refined Apple-native minimalism (type + space do the work).
- **Decoration level:** minimal, with ONE signature — the aurora wash (below).
- **Mood:** Calm, premium, native. The product gets out of the way.
- **Three brand signatures** (carry all distinctiveness so the native SF type can stay neutral):
  1. The **chevron logomark** (the `M`-stroke: `M5.5 26.5 L5.5 5.5 L16 19 L26.5 5.5 L26.5 26.5`).
     - **Menubar mark — the M-crown** (adopted 2026-07-10): the chevron M rendered as a
       solid crown — body `M4.7 13.7 L3.3 3.7 L11 10.5 L18.7 3.7 L17.3 13.7 Z`, jewel
       `circle(11, 5.0, r=1.7)`, band `rect(3.8, 15.5, 14.4×3.2, rx=1.4)` on a 22×22 grid.
       Two readings: the M (peaks + valley) and the crown (The Prince — the name's story).
       Always a solid monochrome silhouette in the menubar (template image); assets live in
       `macos/Macaveli/Assets.xcassets/MenuBarIcon.imageset/`.
  2. The **mono keycap motif** — monospace for keycaps, hotkey glyphs, version tags, eyebrow labels.
  3. The **aurora wash** — a low-opacity cyan→pink radial, hero + first-run only.

## Typography
- **Display + Body + UI:** **SF Pro** via the system stack
  `-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Inter, system-ui, sans-serif`.
  - *Rationale:* renders real SF on every Apple device (the entire audience) and reinforces
    "belongs on your Mac." This is a **principled** use of the system font, not a default —
    a custom display face would fight the native feel. Do not swap it for Inter/Geist/etc.
- **Signature / keycaps / labels / data:** **JetBrains Mono** (free; or **Berkeley Mono** if
  licensed). Load on web via Google Fonts (`JetBrains+Mono:wght@400;500;600`). In the macOS
  app, `Font.system(.body, design: .monospaced)` (SF Mono) is the native equivalent — keep
  the same role (keycaps, hotkey glyphs, version tags, mono eyebrow labels).
  - *Risk (deliberate):* mono is pushed past keycaps into section labels and hero eyebrows.
    Keep it for short strings only — never body copy.
- **Code:** JetBrains Mono / SF Mono.
- **Scale (web):** clamp-based modular scale (hero `clamp(2.4rem,5.5vw,4rem)`, already in `globals.css`).
- **Scale (app):** native macOS type ramp (`.largeTitle`/`.title`/`.headline`/`.body`/`.caption`).

## Color
- **Approach:** restrained — one functional accent + neutrals; color is rare and meaningful.
- **Canvas:** `#FAFAF9` warm off-white (light) · `#0E0E10` near-black (dark)
- **Surface:** `#FFFFFF` / `#17171A`  ·  **Surface-2:** `#F2F1EE` / `#1E1E22`
- **Ink:** `#18181B` primary · `#6B6B70` muted · `#9A9AA0` faint
  (dark: `#F4F4F5` / `#A1A1AA` / `#71717A`)
- **Accent (interactive only):** `#2563EB` electric blue · pressed `#1D4ED8`
  (dark: `#3B82F6`). The one functional accent — links, primary CTAs, focus.
- **Signature atmosphere — aurora wash:** `#7DD3FC` (cyan) → `#F472B6` (pink),
  low opacity (~0.20–0.30 light, ~0.12–0.16 dark), radial. **Hero + first-run ONLY.
  Never behind body text.**
- **Semantic:** success `#16A34A` · warning `#D97706` · error `#DC2626` · info = accent.
- **Dark mode:** redesign surfaces (not a raw invert); drop saturation ~12%.

## Spacing
- **Base unit:** 4px
- **Density:** comfortable in-app · spacious on the marketing hero
- **Scale:** 2xs(2) xs(4) sm(8) md(16) lg(24) xl(32) 2xl(48) 3xl(64)

## Layout
- **Approach:** hybrid — calm HIG surface hierarchy in-app; composition-first
  ("first viewport as poster") on marketing.
- **Risk (deliberate):** marketing breaks the centered-everything pattern — use an
  asymmetric / left-aligned editorial moment for the pillars + hotkeys (avoids the
  AI-slop centered grid flagged in the design review).
- **Max content width (web):** ~1080–1152px.
- **Border radius:** sm 6px (keycaps) · md 9–11px (inputs/cards) · lg 14–18px (windows/heroes) · full 9999px (pills/buttons).

## Motion
- **Approach:** minimal-functional in-app (fast, no countdown/nag) · intentional on marketing.
- **Signature moment:** the first-run "celebrate" when the user's first alt-drag succeeds —
  the single expressive animation in the whole product.
- **Easing:** enter `ease-out` · exit `ease-in` · move `ease-in-out`
- **Duration:** micro 50–100ms · short 150–250ms · medium 250–400ms · long 400–700ms

## Anti-slop guardrails (do NOT do)
- No purple/violet gradient as accent (the aurora is cyan→pink atmosphere, not a button).
- No 3-column icon-in-circle feature grid (the current landing `Pillars` must move off this).
- No centered-everything. No uniform bubble-radius. No decorative blobs/dividers.
- No gradient CTA buttons. CTAs are solid `#2563EB` pills.
- Mono is a signature, not body text. SF is the native voice, not a fallback.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-25 | Initial design system created | `/design-consultation`. North star "one install, your Mac is ready"; Apple-native minimalism; SF Pro + JetBrains Mono signature; aurora wash; 3 deliberate risks (mono signature, aurora, asymmetric landing). Preview: `~/.gstack/projects/jaequery-macaveli/designs/design-system-20260525/preview.html` |
