import versionInfo from "../version.json";

const VERSION = versionInfo.version;
const DOWNLOAD_URL = versionInfo.downloadUrl;
const RELEASES_URL = "https://github.com/jaequery/macaveli/releases/latest";
const REPO_URL = "https://github.com/jaequery/macaveli";

export default function Page() {
  return (
    <main className="min-h-screen bg-[var(--canvas)] text-[var(--ink)]">
      <Nav />
      <Hero />
      <Inside />
      <FounderNote />
      <Hotkeys />
      <CallToAction />
      <Footer />
    </main>
  );
}

// ---------------------------------------------------------------------------
// Nav
// ---------------------------------------------------------------------------

function Nav() {
  return (
    <nav className="mx-auto flex max-w-6xl items-center justify-between px-8 py-6">
      <a href="/" className="flex items-center gap-2.5">
        <Logo />
        <span className="text-[15px] font-semibold tracking-tight">Macaveli</span>
        <span className="font-mono text-[11px] text-[var(--ink-faint)]">v{VERSION}</span>
      </a>

      <div className="hidden gap-9 text-sm text-[var(--ink-muted)] sm:flex">
        <a href="#inside" className="transition hover:text-[var(--ink)]">
          What&rsquo;s inside
        </a>
        <a href="#hotkeys" className="transition hover:text-[var(--ink)]">
          Hotkeys
        </a>
        <a href="/changelog" className="transition hover:text-[var(--ink)]">
          Changelog
        </a>
        <a href={REPO_URL} target="_blank" rel="noreferrer" className="transition hover:text-[var(--ink)]">
          GitHub
        </a>
      </div>

      <a
        href={DOWNLOAD_URL}
        className="rounded-full bg-[var(--accent)] px-5 py-2 text-sm font-semibold text-white transition hover:bg-[var(--accent-press)]"
      >
        Download
      </a>
    </nav>
  );
}

// ---------------------------------------------------------------------------
// Hero — poster composition, aurora wash (the one decorative move)
// ---------------------------------------------------------------------------

function Hero() {
  return (
    <section className="aurora-wash">
      <div className="mx-auto max-w-6xl px-8 pb-32 pt-20 text-center">
        <p className="mb-6 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // one install, your Mac is ready
        </p>

        <h1
          className="font-bold tracking-[-0.04em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2.75rem, 7.5vw, 6rem)", lineHeight: 1 }}
        >
          One app.
          <br />
          Replace twelve.
        </h1>

        <p className="mx-auto mt-8 max-w-2xl text-pretty text-[22px] leading-[1.45] text-[var(--ink-muted)]">
          Everything you reinstall on a new Mac &mdash; window control, screenshots,
          clipboard, recording &mdash; in one calm menubar app that feels like it
          shipped with macOS. Hold <Kbd>ctrl</Kbd> <Kbd>cmd</Kbd>, drag any window
          from anywhere.
        </p>

        <p className="mx-auto mt-5 font-mono text-[13px] text-[var(--ink-faint)]">
          free · open source · no dock icon · no telemetry · no signup
        </p>

        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={DOWNLOAD_URL}
            className="rounded-full bg-[var(--accent)] px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-[var(--accent-press)]"
          >
            Download for Mac
          </a>
          <a
            href="#inside"
            className="text-[15px] font-semibold text-[var(--accent)] transition hover:opacity-70"
          >
            What it replaces &rarr;
          </a>
        </div>

        <AltDragShowcase />
      </div>
    </section>
  );
}

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd
      className="rounded-md border px-1.5 py-0.5 font-mono text-[16px]"
      style={{ background: "var(--cap-bg)", borderColor: "var(--cap-line)", color: "var(--ink)" }}
    >
      {children}
    </kbd>
  );
}

// ---------------------------------------------------------------------------
// Alt-drag showcase — depicts the ONE unique capability: grabbing a window
// from anywhere and moving it. The dashed ghost is the origin; the solid
// window is where it's been dragged to, with a cursor mid-surface + key HUD.
// TODO(T6): replace this stylized mock with a real screen recording of the
// alt-drag, captured with Macaveli's own recorder.
// ---------------------------------------------------------------------------

function AltDragShowcase() {
  return (
    <div className="mt-24">
      <div
        className="relative mx-auto aspect-[16/9] max-w-5xl overflow-hidden rounded-3xl"
        style={{
          background: "linear-gradient(180deg, #2b2b34 0%, #16161c 100%)",
          boxShadow: "var(--shadow)",
        }}
      >
        {/* fake macOS menubar — Macaveli's mark lives here */}
        <div className="absolute left-0 right-0 top-0 flex h-7 items-center gap-4 bg-white/[0.08] px-4 text-[11px] font-medium text-white/85 backdrop-blur">
          <AppleGlyph />
          <span className="font-semibold">Finder</span>
          <span className="hidden sm:inline">File</span>
          <span className="hidden sm:inline">Edit</span>
          <div className="ml-auto flex items-center gap-3 text-white/70">
            <Logo size={12} className="text-white/90" />
            <span className="font-mono text-[10px]">100%</span>
            <span className="font-mono text-[10px]">Wed 7:45</span>
          </div>
        </div>

        {/* ghost origin — where the window started */}
        <div className="absolute left-[8%] top-[20%] h-[55%] w-[42%] rounded-xl border border-dashed border-white/15" />

        {/* the window mid-drag, offset toward center */}
        <div
          className="absolute left-[33%] top-[30%] flex h-[58%] w-[44%] flex-col overflow-hidden rounded-xl border border-white/10"
          style={{
            background: "linear-gradient(180deg, #2c2c36 0%, #1c1c24 100%)",
            boxShadow: "0 28px 50px rgba(0,0,0,0.5)",
          }}
        >
          <div className="flex h-7 items-center gap-1.5 border-b border-white/5 bg-white/[0.04] px-3">
            <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" />
            <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" />
          </div>
          <div className="flex-1 space-y-2.5 p-4">
            <div className="h-2 w-2/3 rounded" style={{ background: "rgba(96,165,250,0.5)" }} />
            <div className="h-2 w-5/6 rounded bg-white/15" />
            <div className="h-2 w-4/5 rounded bg-white/15" />
            <div className="h-2 w-3/4 rounded bg-white/15" />
            <div className="h-2 w-2/3 rounded bg-white/15" />
          </div>
        </div>

        {/* cursor grabbing the window mid-surface (not the title bar) */}
        <div className="absolute left-[53%] top-[58%]">
          <CursorGlyph />
          <div
            className="mt-1 flex items-center gap-1 rounded-lg px-2 py-1.5 backdrop-blur"
            style={{ background: "rgba(20,20,24,0.82)", boxShadow: "0 8px 20px rgba(0,0,0,0.4)" }}
          >
            <HudCap>ctrl</HudCap>
            <span className="text-[10px] text-white/40">+</span>
            <HudCap>cmd</HudCap>
            <span className="text-[10px] text-white/40">+</span>
            <HudCap wide>drag</HudCap>
          </div>
        </div>
      </div>

      <p className="mt-6 text-center font-mono text-[13px] text-[var(--ink-faint)]">
        // grab any window, anywhere &mdash; no title bar, no corner-hunting
      </p>
    </div>
  );
}

function HudCap({ children, wide = false }: { children: React.ReactNode; wide?: boolean }) {
  return (
    <span
      className={`font-mono text-[10.5px] font-semibold text-white/90 ${wide ? "rounded-full px-2.5" : "rounded px-1.5"} py-1`}
      style={{ background: "rgba(255,255,255,0.1)", border: "1px solid rgba(255,255,255,0.14)" }}
    >
      {children}
    </span>
  );
}

function CursorGlyph() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path
        d="M5 3 L5 19 L9.5 14.5 L12.5 21 L15 20 L12 13.5 L18 13.5 Z"
        fill="white"
        stroke="rgba(0,0,0,0.55)"
        strokeWidth="1"
        strokeLinejoin="round"
      />
    </svg>
  );
}

// ---------------------------------------------------------------------------
// What's inside — editorial rows (NOT a 3-column card grid), left-aligned.
// Lists all four real capability areas, consistent with "replace twelve" and
// the in-app cheatsheet sections.
// ---------------------------------------------------------------------------

function Inside() {
  const rows: Array<{ label: string; title: string; body: string; replaces: string }> = [
    {
      label: "Window control",
      title: "Move and resize from anywhere.",
      body: "Hold ctrl + cmd and drag any window from any point — no title bar, no corner-hunting. Snap to halves, maximize, re-center in one keystroke each. Quadrant-aware resize. Raycast can't do this.",
      replaces: "Rectangle · Magnet · BetterTouchTool · Loop",
    },
    {
      label: "Screenshots & annotation",
      title: "Capture, mark up, share.",
      body: "Grab a region to the clipboard, then annotate it in place — arrows, text, shapes, select and resize. No round-trip through another app.",
      replaces: "CleanShot X · Shottr · Preview markup",
    },
    {
      label: "Clipboard history",
      title: "Every copy, one keystroke away.",
      body: "A searchable history of what you've copied, kept locally. Pull up the panel, find it, paste it. Nothing leaves your Mac.",
      replaces: "Paste · Maccy · Raycast clipboard",
    },
    {
      label: "Screen recording",
      title: "Record from a hotkey.",
      body: "One hotkey starts and stops a recording of your display. MP4 or GIF, optional optimization pass. No dialogs, no countdown nag, no upload.",
      replaces: "Loom · CleanShot X · QuickTime",
    },
  ];

  return (
    <section id="inside" className="border-t border-[var(--line)] bg-[var(--surface)] px-8 py-32">
      <div className="mx-auto max-w-5xl">
        <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // what&rsquo;s inside
        </p>
        <h2
          className="max-w-2xl font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2rem, 5vw, 3.25rem)", lineHeight: 1.05 }}
        >
          Four tools. One menubar icon.
        </h2>
        <p className="mt-5 max-w-xl text-[17px] leading-relaxed text-[var(--ink-muted)]">
          Each one used to be a separate app, half of them paid. Macaveli does all of
          it, free, in 14 MB.
        </p>

        <div className="mt-16">
          {rows.map((row, i) => (
            <div
              key={row.label}
              className={`grid grid-cols-1 gap-x-12 gap-y-3 py-9 md:grid-cols-[260px_1fr] ${
                i !== 0 ? "border-t border-[var(--line)]" : ""
              }`}
            >
              <div>
                <p className="font-mono text-[12px] font-medium tracking-[0.02em] text-[var(--ink)]">
                  {row.label}
                </p>
                <p className="mt-2 font-mono text-[11px] leading-relaxed text-[var(--ink-faint)]">
                  replaces {row.replaces}
                </p>
              </div>
              <div>
                <h3 className="text-[22px] font-semibold tracking-tight text-[var(--ink)]">
                  {row.title}
                </h3>
                <p className="mt-2.5 max-w-xl text-[16px] leading-[1.55] text-[var(--ink-muted)]">
                  {row.body}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Founder note — the new-Mac origin story (the thesis)
// ---------------------------------------------------------------------------

function FounderNote() {
  return (
    <section className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 py-28">
      <div className="mx-auto max-w-2xl">
        <p className="mb-5 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--ink-faint)]">
          // why it exists
        </p>
        <p className="text-[22px] leading-[1.45] text-[var(--ink)]">
          I got a new MacBook and dreaded the next two hours &mdash; Rectangle,
          CleanShot, Loom, twelve more. Then I noticed I was reinstalling the same
          handful every time. The rest was noise.
        </p>
        <p className="mt-5 text-[19px] leading-[1.55] text-[var(--ink-muted)]">
          Macaveli is what&rsquo;s left when you keep only the essentials and put them
          in one place. Install it once. Skip the other twelve.
        </p>
        <p className="mt-8 text-[14px] font-medium text-[var(--ink-faint)]">&mdash; Jae, founder</p>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Hotkeys — spec table, left-aligned header (breaks the centered rhythm)
// ---------------------------------------------------------------------------

function Hotkeys() {
  const rows: Array<[string, string]> = [
    ["ctrl + cmd + drag", "Move the window under the cursor"],
    ["cmd + shift + drag", "Resize the window under the cursor"],
    ["ctrl + [", "Snap focused window to left half"],
    ["ctrl + ]", "Snap focused window to right half"],
    ["ctrl + cmd + up", "Maximize focused window"],
    ["ctrl + cmd + down", "Re-center focused window"],
    ["ctrl + cmd + R", "Start / stop screen recording"],
  ];

  return (
    <section id="hotkeys" className="border-t border-[var(--line)] bg-[var(--surface-2)] px-8 py-32">
      <div className="mx-auto max-w-3xl">
        <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // default hotkeys
        </p>
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2rem, 5vw, 3.25rem)", lineHeight: 1.05 }}
        >
          Every key, rebindable.
        </h2>
        <p className="mt-4 max-w-md text-[17px] text-[var(--ink-muted)]">
          These ship as defaults. Change any of them in the menu bar popover.
        </p>

        <div className="mt-12 overflow-hidden rounded-2xl border border-[var(--line)] bg-[var(--surface)]">
          {rows.map(([keys, action], i) => (
            <div
              key={keys}
              className={`flex items-center justify-between gap-6 px-6 py-5 ${
                i !== 0 ? "border-t border-[var(--line)]" : ""
              }`}
            >
              <kbd
                className="rounded-md border px-2.5 py-1 font-mono text-[13px] font-medium"
                style={{ background: "var(--cap-bg)", borderColor: "var(--cap-line)", color: "var(--ink)" }}
              >
                {keys}
              </kbd>
              <span className="text-right text-[15px] text-[var(--ink-muted)]">{action}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Closing CTA
// ---------------------------------------------------------------------------

function CallToAction() {
  return (
    <section className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 py-32 text-center">
      <div className="mx-auto max-w-3xl">
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2rem, 5vw, 3.5rem)", lineHeight: 1.05 }}
        >
          Install it. Skip the other twelve.
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-[19px] leading-[1.5] text-[var(--ink-muted)]">
          14 MB. macOS 13+. Free, MIT-licensed, open source. No account, no telemetry,
          no upsell. Ever.
        </p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={DOWNLOAD_URL}
            className="rounded-full bg-[var(--accent)] px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-[var(--accent-press)]"
          >
            Download for Mac
          </a>
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="text-[15px] font-semibold text-[var(--accent)] transition hover:opacity-70"
          >
            View source on GitHub &rarr;
          </a>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

function Footer() {
  return (
    <footer className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 font-mono text-[12px] text-[var(--ink-faint)] sm:flex-row">
        <div className="flex items-center gap-2.5">
          <Logo className="text-[var(--ink-muted)]" />
          <span>Macaveli · MIT · macOS 13+ · v{VERSION}</span>
        </div>
        <div className="flex gap-6">
          <a href="/changelog" className="hover:text-[var(--ink)]">
            Changelog
          </a>
          <a href={REPO_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--ink)]">
            Source
          </a>
          <a href={`${REPO_URL}/issues`} target="_blank" rel="noreferrer" className="hover:text-[var(--ink)]">
            Issues
          </a>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--ink)]">
            Releases
          </a>
        </div>
      </div>
    </footer>
  );
}

// ---------------------------------------------------------------------------
// Bits
// ---------------------------------------------------------------------------

function Logo({ size = 22, className = "" }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden className={className}>
      <path
        d="M5.5 26.5 L5.5 5.5 L16 19 L26.5 5.5 L26.5 26.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="4"
        strokeLinejoin="miter"
        strokeMiterlimit={8}
      />
    </svg>
  );
}

function AppleGlyph() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden className="text-white/85">
      <path d="M17.05 12.04c-.02-2.18 1.78-3.23 1.86-3.28-1.01-1.48-2.59-1.68-3.15-1.7-1.34-.13-2.62.79-3.3.79-.68 0-1.74-.77-2.86-.75-1.47.02-2.83.85-3.59 2.17-1.53 2.65-.39 6.57 1.1 8.72.73 1.05 1.6 2.23 2.74 2.19 1.1-.05 1.51-.71 2.84-.71 1.33 0 1.7.71 2.86.69 1.18-.02 1.93-1.07 2.65-2.12.84-1.22 1.18-2.4 1.2-2.46-.03-.01-2.3-.88-2.35-3.54zM14.93 5.13c.6-.74 1.01-1.76.9-2.79-.87.04-1.94.59-2.56 1.32-.56.65-1.04 1.7-.91 2.7.97.08 1.97-.49 2.57-1.23z" />
    </svg>
  );
}
