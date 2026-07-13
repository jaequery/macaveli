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
      <HotkeyStrip />
      <Features />
      <FounderNote />
      <Trust />
      <CallToAction />
      <Faq />
      <Footer />
    </main>
  );
}

// ---------------------------------------------------------------------------
// Nav — sticky, blurred; the hero visual runs right under it
// ---------------------------------------------------------------------------

function Nav() {
  return (
    <nav
      className="sticky top-0 z-50 border-b backdrop-blur-md"
      style={{
        background: "color-mix(in srgb, var(--canvas) 72%, transparent)",
        borderColor: "color-mix(in srgb, var(--line) 60%, transparent)",
      }}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between px-8 py-5">
        <a href="/" className="flex items-center gap-2.5">
          <Logo />
          <span className="text-[15px] font-semibold tracking-tight">Macaveli</span>
          <span className="font-mono text-[11px] text-[var(--ink-faint)]">v{VERSION}</span>
        </a>

        <div className="hidden gap-9 text-sm text-[var(--ink-muted)] sm:flex">
          <a href="#features" className="transition hover:text-[var(--ink)]">
            Features
          </a>
          <a href="#faq" className="transition hover:text-[var(--ink)]">
            FAQ
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
      </div>
    </nav>
  );
}

// ---------------------------------------------------------------------------
// Hero — poster composition, aurora wash (the one decorative move). The desktop
// visual pulls down over the section seam below it.
// ---------------------------------------------------------------------------

function Hero() {
  return (
    <section className="aurora-wash">
      <div className="mx-auto max-w-6xl px-8 pt-20 text-center">
        <p className="mb-6 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // one install, your Mac is ready
        </p>

        <h1
          className="font-bold tracking-[-0.04em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2.75rem, 7.5vw, 6rem)", lineHeight: 1 }}
        >
          Your Mac,
          <br />
          already set up.
        </h1>

        <p className="mx-auto mt-8 max-w-2xl text-pretty text-[22px] leading-[1.45] text-[var(--ink-muted)]">
          The essential Mac utilities &mdash; window control, screenshots, clipboard,
          recording &mdash; already configured, already there. Hold <Kbd>&#8963;</Kbd>{" "}
          <Kbd>&#8984;</Kbd> and drag any window to see it work.
        </p>

        <p className="mx-auto mt-5 font-mono text-[13px] text-[var(--ink-faint)]">
          free forever · MIT open source · no signup · no telemetry
        </p>

        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={DOWNLOAD_URL}
            className="rounded-full bg-[var(--accent)] px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-[var(--accent-press)]"
          >
            Download for Mac
          </a>
          <a
            href="#features"
            className="text-[15px] font-semibold text-[var(--accent)] transition hover:opacity-70"
          >
            See what&rsquo;s inside &rarr;
          </a>
        </div>

        <HeroDesktop />
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
// Hero desktop — a macOS desktop mid alt-drag: dashed ghost at the origin,
// solid window where it's been dragged, cursor mid-surface + key HUD, plus a
// snapped set-dressing window so the wide frame doesn't feel sparse.
// TODO(T6): replace with a real screen recording captured with Macaveli.
// ---------------------------------------------------------------------------

function HeroDesktop() {
  return (
    <div className="relative z-10 mt-20 mb-[-48px] sm:mb-[-96px]">
      <div
        className="relative mx-auto aspect-[16/9] max-w-6xl overflow-hidden rounded-[18px]"
        style={{
          background: "linear-gradient(180deg, #2b2b34 0%, #16161c 100%)",
          boxShadow: "var(--shadow)",
        }}
        aria-hidden
      >
        {/* fake macOS menubar — Macaveli's mark lives here */}
        <div className="absolute left-0 right-0 top-0 z-10 flex h-7 items-center gap-4 bg-white/[0.08] px-4 text-[11px] font-medium text-white/85 backdrop-blur">
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

        {/* set-dressing: a window already snapped to the left edge */}
        <div
          className="absolute left-[3%] top-[14%] hidden h-[74%] w-[26%] flex-col overflow-hidden rounded-lg border border-white/[0.07] opacity-60 sm:flex"
          style={{ background: "linear-gradient(180deg, #26262e 0%, #1a1a21 100%)" }}
        >
          <div className="flex h-6 items-center gap-1.5 border-b border-white/5 bg-white/[0.03] px-2.5">
            <span className="h-2 w-2 rounded-full bg-white/20" />
            <span className="h-2 w-2 rounded-full bg-white/20" />
            <span className="h-2 w-2 rounded-full bg-white/20" />
          </div>
          <div className="flex-1 space-y-2 p-3">
            <div className="h-1.5 w-3/4 rounded bg-white/10" />
            <div className="h-1.5 w-2/3 rounded bg-white/10" />
            <div className="h-1.5 w-4/5 rounded bg-white/10" />
            <div className="h-1.5 w-1/2 rounded bg-white/10" />
          </div>
        </div>

        {/* ghost origin — where the window started */}
        <div className="absolute left-[34%] top-[18%] h-[52%] w-[36%] rounded-xl border border-dashed border-white/15" />

        {/* the window mid-drag, offset toward the right */}
        <div
          className="absolute left-[50%] top-[30%] flex h-[56%] w-[38%] flex-col overflow-hidden rounded-xl border border-white/10"
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
        <div className="absolute left-[66%] top-[56%]">
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
// Hotkey strip — the logo-strip slot, without logos. A quiet rail of the
// shortcuts that come pre-bound. Extra top padding absorbs the hero overlap.
// ---------------------------------------------------------------------------

function HotkeyStrip() {
  const items: Array<[string, string]> = [
    ["⌃⌘ drag", "move"],
    ["⌘⇧ drag", "resize"],
    ["⌃⌘4", "screenshot"],
    ["⌃⌘A", "annotate"],
    ["⌃⌘P", "clipboard"],
    ["⌃⌘R", "record"],
    ["⌃⌘E", "eyedropper"],
  ];

  return (
    <section className="border-b border-[var(--line)] bg-[var(--canvas)] px-8 pb-8 pt-[88px] sm:pt-[144px]">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-center gap-x-8 gap-y-3">
        {items.map(([keys, label]) => (
          <span key={label} className="flex items-center gap-2">
            <kbd
              className="rounded-md border px-1.5 py-0.5 font-mono text-[11px] font-medium"
              style={{ background: "var(--cap-bg)", borderColor: "var(--cap-line)", color: "var(--ink)" }}
            >
              {keys}
            </kbd>
            <span className="font-mono text-[12px] text-[var(--ink-faint)]">{label}</span>
          </span>
        ))}
      </div>
      <p className="mt-5 text-center font-mono text-[12px] text-[var(--ink-faint)]">
        // every shortcut, out of the box &mdash; and every one of them rebindable
      </p>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Features — centered intro + six zigzag rows, each with a stylized macOS mock
// ---------------------------------------------------------------------------

type Feature = {
  eyebrow: string;
  title: string;
  body: React.ReactNode;
  keycaps: Array<[string, string]>;
  visual: React.ReactNode;
};

function Features() {
  const features: Feature[] = [
    {
      eyebrow: "move anything, anywhere",
      title: "Grab any window. Not just the title bar.",
      body: (
        <>
          Hold &#8963;&#8984; and drag from anywhere on the window &mdash; no hunting
          for a title bar, no fighting a cramped corner. &#8984;&#8679;-drag resizes
          the same way, and it knows where you grabbed: a corner resizes that corner,
          the center resizes evenly from the middle. Snap a window to a half, maximize
          it, or center it without touching the mouse again.
        </>
      ),
      keycaps: [
        ["⌃⌘ drag", "move"],
        ["⌘⇧ drag", "resize"],
        ["⌃[", "left half"],
        ["⌃]", "right half"],
        ["⌃⌘↑", "maximize"],
        ["⌃⌘↓", "center"],
      ],
      visual: <WindowControlMock />,
    },
    {
      eyebrow: "capture, mark up, done",
      title: "Screenshot, annotate, and sample color — instantly.",
      body: (
        <>
          &#8963;&#8984;4 grabs a region straight to your clipboard, with a quick toast
          to confirm. &#8963;&#8984;A opens whatever image is on that clipboard in a
          lightweight annotator &mdash; arrows, text, shapes, all selectable, movable,
          and resizable &mdash; so there&rsquo;s no round-trip through Preview. Need a
          hex code instead of a screenshot? &#8963;&#8984;E samples any pixel on screen
          and copies it straight to your clipboard.
        </>
      ),
      keycaps: [
        ["⌃⌘4", "screenshot"],
        ["⌃⌘A", "annotate"],
        ["⌃⌘E", "eyedropper"],
      ],
      visual: <CaptureMock />,
    },
    {
      eyebrow: "never lose a copy",
      title: "Everything you've copied, searchable, right there.",
      body: (
        <>
          &#8963;&#8984;P opens a panel of your clipboard history &mdash; text and
          images alike, with thumbnails and custom labels so you can find the one you
          meant. It&rsquo;s a private log, not a synced service: everything stays on
          your Mac.
        </>
      ),
      keycaps: [["⌃⌘P", "history"]],
      visual: <ClipboardMock />,
    },
    {
      eyebrow: "record without the friction",
      title: "Screen recording that doesn't get in your way.",
      body: (
        <>
          &#8963;&#8984;R starts and stops a recording &mdash; no countdown, no
          watermark, no upload prompt. Export to MP4 or GIF, add a draggable camera
          overlay, and capture system audio if you need it.
        </>
      ),
      keycaps: [["⌃⌘R", "start / stop"]],
      visual: <RecordingMock />,
    },
    {
      eyebrow: "stay awake, safely",
      title: "Stay awake — without draining your battery.",
      body: (
        <>
          Three levels: off, awake while the lid&rsquo;s open, or awake even with the
          lid closed. That last mode only arms on AC power, and a tiny watchdog
          switches it off the instant you unplug &mdash; so it can&rsquo;t quietly
          kill your battery on the way out the door.
        </>
      ),
      keycaps: [],
      visual: <NeverSleepMock />,
    },
    {
      eyebrow: "type at your speed",
      title: "Key repeat, tuned faster than macOS allows.",
      body: (
        <>
          Set repeat speed and delay past the limits of System Settings&rsquo; own
          sliders, or tap the one-touch Fast preset and stop thinking about it. Built
          for anyone who lives in a terminal or an editor and finds the stock defaults
          sluggish.
        </>
      ),
      keycaps: [],
      visual: <KeyboardMock />,
    },
  ];

  return (
    <section id="features" className="bg-[var(--surface)] px-8 pb-32 pt-24">
      <div className="mx-auto max-w-3xl text-center">
        <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // the essentials
        </p>
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2rem, 5vw, 3.25rem)", lineHeight: 1.05 }}
        >
          Everything a Mac needs. Nothing to set up.
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-[17px] leading-relaxed text-[var(--ink-muted)]">
          Each one bound to a single hotkey, configured before you ever open the app.
        </p>
      </div>

      <div className="mx-auto mt-24 max-w-6xl space-y-28 lg:space-y-[120px]">
        {features.map((f, i) => (
          <div
            key={f.eyebrow}
            className={`flex flex-col gap-12 lg:items-center lg:gap-16 ${
              i % 2 === 1 ? "lg:flex-row-reverse" : "lg:flex-row"
            }`}
          >
            <div className="shrink-0 lg:max-w-[420px] lg:basis-5/12">
              <p className="font-mono text-[12px] font-medium tracking-[0.02em] text-[var(--accent)]">
                {f.eyebrow}
              </p>
              <h3 className="mt-3 text-[28px] font-semibold leading-tight tracking-tight text-[var(--ink)]">
                {f.title}
              </h3>
              <p className="mt-3 text-[15px] leading-[1.6] text-[var(--ink-muted)]">{f.body}</p>
              {f.keycaps.length > 0 && (
                <div className="mt-5 flex flex-wrap gap-x-4 gap-y-2">
                  {f.keycaps.map(([keys, label]) => (
                    <span key={keys} className="flex items-center gap-1.5">
                      <kbd
                        className="rounded-md border px-1.5 py-0.5 font-mono text-[11px] font-medium"
                        style={{ background: "var(--cap-bg)", borderColor: "var(--cap-line)", color: "var(--ink)" }}
                      >
                        {keys}
                      </kbd>
                      <span className="font-mono text-[11px] text-[var(--ink-faint)]">{label}</span>
                    </span>
                  ))}
                </div>
              )}
            </div>

            <div className="min-w-0 flex-1">
              <div
                className="flex aspect-[4/3] items-center justify-center rounded-[18px] border border-[var(--line)] bg-[var(--surface-2)] p-6 sm:p-8"
                style={{ boxShadow: "var(--shadow-card)" }}
              >
                {f.visual}
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Feature mocks — stylized macOS UI, all decorative (aria-hidden). Dark desktop
// chrome for whole-screen actions (window control, recording — ties them to the
// hero); light native chrome for panel-scale features.
// ---------------------------------------------------------------------------

function WindowControlMock() {
  return (
    <div
      aria-hidden
      className="relative h-[88%] w-[94%] overflow-hidden rounded-[11px]"
      style={{ background: "linear-gradient(180deg, #2b2b34 0%, #16161c 100%)" }}
    >
      {/* faint quadrant grid */}
      <div className="absolute inset-0 grid grid-cols-3 grid-rows-3">
        {Array.from({ length: 9 }).map((_, i) => (
          <div key={i} className="border border-white/[0.05]" />
        ))}
      </div>

      {/* window snapped to the left half */}
      <div
        className="absolute left-[3.5%] top-[7%] flex h-[86%] w-[44%] flex-col overflow-hidden rounded-lg border border-white/10"
        style={{ background: "linear-gradient(180deg, #2c2c36 0%, #1c1c24 100%)" }}
      >
        <div className="flex h-6 items-center gap-1.5 border-b border-white/5 bg-white/[0.04] px-2.5">
          <span className="h-2 w-2 rounded-full bg-[#ff5f57]" />
          <span className="h-2 w-2 rounded-full bg-[#febc2e]" />
          <span className="h-2 w-2 rounded-full bg-[#28c840]" />
        </div>
        <div className="flex-1 space-y-2 p-3">
          <div className="h-1.5 w-2/3 rounded" style={{ background: "rgba(96,165,250,0.5)" }} />
          <div className="h-1.5 w-5/6 rounded bg-white/15" />
          <div className="h-1.5 w-3/4 rounded bg-white/15" />
          <div className="h-1.5 w-4/5 rounded bg-white/15" />
        </div>
      </div>

      {/* ghost target on the right half */}
      <div className="absolute right-[3.5%] top-[7%] h-[86%] w-[44%] rounded-lg border border-dashed border-white/20" />

      {/* snap motion arrow */}
      <svg
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
        width="36"
        height="16"
        viewBox="0 0 36 16"
        fill="none"
      >
        <path d="M2 8 H30 M24 2 L30 8 L24 14" stroke="rgba(255,255,255,0.4)" strokeWidth="2" strokeLinecap="round" />
      </svg>

      {/* HUD */}
      <div
        className="absolute bottom-3 left-3 flex items-center gap-1 rounded-lg px-2 py-1.5"
        style={{ background: "rgba(20,20,24,0.82)" }}
      >
        <HudCap>ctrl</HudCap>
        <span className="text-[10px] text-white/40">+</span>
        <HudCap>cmd</HudCap>
        <span className="text-[10px] text-white/40">+</span>
        <HudCap wide>drag</HudCap>
      </div>
    </div>
  );
}

function CaptureMock() {
  return (
    <div
      aria-hidden
      className="relative flex h-[88%] w-[92%] flex-col overflow-hidden rounded-[11px] border border-[var(--line)] bg-[var(--surface)]"
      style={{ boxShadow: "0 12px 28px rgba(0,0,0,0.12)" }}
    >
      <div className="flex h-7 items-center gap-1.5 border-b border-[var(--line)] px-3">
        <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" />
      </div>

      <div className="relative flex-1 p-4">
        {/* the captured "app" — abstract content */}
        <div className="space-y-2.5">
          <div className="h-2 w-1/2 rounded bg-[var(--surface-2)]" />
          <div className="h-2 w-3/4 rounded bg-[var(--surface-2)]" />
          <div className="h-16 w-full rounded-md bg-[var(--surface-2)]" />
          <div className="h-2 w-2/3 rounded bg-[var(--surface-2)]" />
        </div>

        {/* selection marquee */}
        <div className="absolute left-[10%] top-[26%] h-[52%] w-[62%] rounded-md border border-dashed border-[var(--accent)]" />

        {/* drawn annotation arrow */}
        <svg
          className="absolute left-[22%] top-[38%]"
          width="90"
          height="46"
          viewBox="0 0 90 46"
          fill="none"
        >
          <path
            d="M4 42 C 30 30, 52 20, 78 8 M68 6 L78 8 L74 17"
            stroke="var(--accent)"
            strokeWidth="2"
            strokeLinecap="round"
          />
        </svg>

        {/* floating annotation toolbar */}
        <div
          className="absolute left-1/2 top-[12%] flex -translate-x-1/2 items-center gap-2.5 rounded-full border border-[var(--line)] bg-[var(--surface)] px-3.5 py-1.5"
          style={{ boxShadow: "0 8px 20px rgba(0,0,0,0.12)" }}
        >
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
            <path d="M2 12 L12 2 M12 2 H6 M12 2 V8" stroke="var(--ink-muted)" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
          <span className="h-3 w-3 rounded-[3px] border-[1.5px] border-[var(--ink-muted)]" />
          <span className="text-[11px] font-semibold leading-none text-[var(--ink-muted)]">T</span>
          <svg width="13" height="13" viewBox="0 0 13 13" fill="none">
            <path d="M2 11 L9 4 L11 6 L4 13 Z M9 4 L11 2 L13 4 L11 6" stroke="var(--ink-muted)" strokeWidth="1.3" />
          </svg>
          <span className="h-3.5 w-3.5 rounded-full bg-[var(--accent)]" />
        </div>

        {/* picked-color chip — the eyedropper's output */}
        <div className="absolute bottom-3 right-3 flex items-center gap-1.5 rounded-md border border-[var(--line)] bg-[var(--surface)] px-2 py-1">
          <span className="h-3 w-3 rounded-[3px] bg-[var(--accent)]" />
          <span className="font-mono text-[10px] text-[var(--ink-muted)]">#2563EB</span>
        </div>
      </div>
    </div>
  );
}

function ClipboardMock() {
  const rows: Array<{ icon: React.ReactNode; width: string; time: string; highlight?: boolean }> = [
    {
      icon: <span className="text-[9px] font-semibold text-[var(--ink-muted)]">Aa</span>,
      width: "w-3/4",
      time: "2m",
    },
    {
      icon: (
        <span
          className="h-4 w-4 rounded-[3px]"
          style={{ background: "linear-gradient(135deg, #7dd3fc 0%, #f472b6 100%)", opacity: 0.7 }}
        />
      ),
      width: "w-1/2",
      time: "14m",
      highlight: true,
    },
    {
      icon: <span className="h-3 w-3 rounded-[3px] bg-[var(--accent)]" />,
      width: "w-2/5",
      time: "1h",
    },
    {
      icon: <span className="text-[9px] font-semibold text-[var(--ink-muted)]">Aa</span>,
      width: "w-4/5",
      time: "3h",
    },
    {
      icon: <span className="text-[9px] font-semibold text-[var(--ink-muted)]">Aa</span>,
      width: "w-2/3",
      time: "1d",
    },
  ];

  return (
    <div
      aria-hidden
      className="flex h-[92%] w-[64%] max-w-[280px] flex-col overflow-hidden rounded-[14px] border border-[var(--line)] bg-[var(--surface)]"
      style={{ boxShadow: "0 12px 28px rgba(0,0,0,0.12)" }}
    >
      {/* search field */}
      <div className="p-3">
        <div className="flex items-center gap-2 rounded-full border border-[var(--line)] bg-[var(--surface-2)] px-3 py-1.5">
          <svg width="11" height="11" viewBox="0 0 12 12" fill="none">
            <circle cx="5" cy="5" r="3.5" stroke="var(--ink-faint)" strokeWidth="1.5" />
            <path d="M8 8 L11 11" stroke="var(--ink-faint)" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
          <span className="h-1.5 w-16 rounded bg-[var(--cap-bg)]" />
        </div>
      </div>

      {/* history rows */}
      <div className="flex-1">
        {rows.map((row, i) => (
          <div
            key={i}
            className="flex items-center gap-2.5 border-t border-[var(--line)] px-3.5 py-2.5"
            style={
              row.highlight
                ? { background: "color-mix(in srgb, var(--accent) 6%, transparent)" }
                : undefined
            }
          >
            <span className="flex h-4 w-4 shrink-0 items-center justify-center">{row.icon}</span>
            <span className={`h-1.5 ${row.width} rounded bg-[var(--cap-bg)]`} />
            <span className="ml-auto font-mono text-[9px] text-[var(--ink-faint)]">{row.time}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

function RecordingMock() {
  return (
    <div
      aria-hidden
      className="relative h-[88%] w-[94%] overflow-hidden rounded-[11px]"
      style={{ background: "linear-gradient(180deg, #2b2b34 0%, #16161c 100%)" }}
    >
      {/* fake menubar with recording badge on the mark */}
      <div className="flex h-6 items-center gap-3 bg-white/[0.08] px-3 text-[10px] font-medium text-white/80">
        <AppleGlyph />
        <div className="ml-auto flex items-center gap-3 text-white/70">
          <span className="relative">
            <Logo size={11} className="text-white/90" />
            <span className="absolute -right-1 -top-1 h-1.5 w-1.5 rounded-full bg-[#f87171]" />
          </span>
          <span className="font-mono text-[9px]">Wed 7:45</span>
        </div>
      </div>

      {/* capture region */}
      <div className="absolute left-[12%] top-[22%] h-[62%] w-[64%] rounded-md border border-dashed border-[var(--accent)]" />

      {/* recording HUD */}
      <div
        className="absolute left-1/2 top-[10%] flex -translate-x-1/2 items-center gap-2 rounded-full px-3 py-1.5"
        style={{ background: "rgba(20,20,24,0.85)", boxShadow: "0 8px 20px rgba(0,0,0,0.4)" }}
      >
        <span className="h-2 w-2 animate-pulse rounded-full bg-[#f87171]" />
        <span className="font-mono text-[10px] font-medium text-white/90">00:12</span>
        <span className="ml-1 flex h-3.5 w-3.5 items-center justify-center rounded-full border border-white/25">
          <span className="h-1.5 w-1.5 rounded-[1px] bg-white/80" />
        </span>
      </div>

      {/* draggable camera overlay */}
      <div
        className="absolute bottom-[8%] right-[7%] flex h-14 w-14 items-center justify-center rounded-full border-2 border-white/25"
        style={{ background: "linear-gradient(135deg, #3a3a46 0%, #23232b 100%)" }}
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="rgba(255,255,255,0.35)">
          <circle cx="12" cy="9" r="4" />
          <path d="M4 21 C4 16.5, 8 14.5, 12 14.5 C16 14.5, 20 16.5, 20 21 Z" />
        </svg>
      </div>
    </div>
  );
}

function NeverSleepMock() {
  const options: Array<{ label: string; caption?: string; selected?: boolean }> = [
    { label: "Off" },
    { label: "While the lid is open" },
    { label: "Even with the lid closed", caption: "arms on AC only · auto-off on unplug", selected: true },
  ];

  return (
    <div
      aria-hidden
      className="w-[78%] max-w-[340px] overflow-hidden rounded-[11px] border border-[var(--line)] bg-[var(--surface)]"
      style={{ boxShadow: "0 12px 28px rgba(0,0,0,0.12)" }}
    >
      <div className="border-b border-[var(--line)] px-4 py-2.5">
        <span className="text-[12px] font-semibold text-[var(--ink)]">Never Sleep</span>
      </div>
      {options.map((opt) => (
        <div key={opt.label} className="flex items-start gap-2.5 border-t border-[var(--line)] px-4 py-3 first:border-t-0">
          <span
            className={`mt-0.5 flex h-3.5 w-3.5 shrink-0 items-center justify-center rounded-full border ${
              opt.selected ? "border-[var(--accent)]" : "border-[var(--cap-line)]"
            }`}
            style={opt.selected ? { background: "var(--accent)" } : undefined}
          >
            {opt.selected && <span className="h-1.5 w-1.5 rounded-full bg-white" />}
          </span>
          <span className="min-w-0">
            <span className={`block text-[12px] ${opt.selected ? "font-medium text-[var(--ink)]" : "text-[var(--ink-muted)]"}`}>
              {opt.label}
            </span>
            {opt.caption && (
              <span className="mt-0.5 block font-mono text-[9.5px] text-[var(--ink-faint)]">{opt.caption}</span>
            )}
          </span>
        </div>
      ))}
    </div>
  );
}

function KeyboardMock() {
  return (
    <div
      aria-hidden
      className="w-[78%] max-w-[340px] overflow-hidden rounded-[11px] border border-[var(--line)] bg-[var(--surface)]"
      style={{ boxShadow: "0 12px 28px rgba(0,0,0,0.12)" }}
    >
      <div className="border-b border-[var(--line)] px-4 py-2.5">
        <span className="text-[12px] font-semibold text-[var(--ink)]">Key Repeat</span>
      </div>

      <div className="space-y-4 px-4 py-4">
        <div>
          <div className="flex items-center justify-between">
            <span className="text-[11px] text-[var(--ink-muted)]">Repeat speed</span>
            <span className="font-mono text-[10px] text-[var(--ink-faint)]">fast</span>
          </div>
          <MockSlider fill={0.85} />
        </div>
        <div>
          <div className="flex items-center justify-between">
            <span className="text-[11px] text-[var(--ink-muted)]">Delay until repeat</span>
            <span className="font-mono text-[10px] text-[var(--ink-faint)]">short</span>
          </div>
          <MockSlider fill={0.2} />
        </div>
        <div className="flex items-center gap-2 pt-1">
          <span className="rounded-full bg-[var(--accent)] px-3 py-1 text-[11px] font-semibold text-white">Fast</span>
          <span
            className="rounded-full border px-3 py-1 text-[11px] font-medium text-[var(--ink-muted)]"
            style={{ borderColor: "var(--cap-line)" }}
          >
            Default
          </span>
          <span className="ml-auto font-mono text-[9.5px] text-[var(--ink-faint)]">beyond System Settings</span>
        </div>
      </div>
    </div>
  );
}

function MockSlider({ fill }: { fill: number }) {
  return (
    <div className="relative mt-2 h-1 rounded-full bg-[var(--cap-bg)]">
      <div
        className="absolute left-0 top-0 h-1 rounded-full bg-[var(--accent)]"
        style={{ width: `${fill * 100}%` }}
      />
      <span
        className="absolute top-1/2 h-3.5 w-3.5 -translate-y-1/2 rounded-full border border-[var(--line)] bg-white"
        style={{ left: `calc(${fill * 100}% - 7px)`, boxShadow: "0 1px 4px rgba(0,0,0,0.2)" }}
      />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Founder note — the testimonial slot, used honestly (no customer quotes to
// fake). The new-Mac origin story.
// ---------------------------------------------------------------------------

function FounderNote() {
  return (
    <section className="bg-[var(--canvas)] px-8 py-28">
      <div
        className="mx-auto max-w-2xl rounded-[18px] border border-[var(--line)] bg-[var(--surface)] px-8 py-14 text-center sm:px-14"
        style={{ boxShadow: "var(--shadow-card)" }}
      >
        <Logo size={28} className="mx-auto mb-8 text-[var(--ink-faint)]" />

        <p className="mx-auto max-w-[46ch] text-[20px] leading-[1.55] text-[var(--ink)]">
          &ldquo;I got a new MacBook and did what I always do: started listing
          everything I&rsquo;d need to install and configure before it felt like mine.
          Window snapping. A decent screenshot tool. Clipboard history. About an hour
          in, I realized I was rebuilding the same afternoon I&rsquo;d already lost
          the last time I did this.
        </p>
        <p className="mx-auto mt-5 max-w-[46ch] text-[20px] leading-[1.55] text-[var(--ink)]">
          So I stopped listing and started building &mdash; one menubar app with sane
          defaults for the stuff every Mac needs, ready the moment you install it.
          It&rsquo;s free, it&rsquo;s open source, and it&rsquo;s the app I wished
          existed the day I unboxed this laptop.&rdquo;
        </p>

        <div className="mt-10 flex items-center justify-center gap-3">
          <span
            className="flex h-11 w-11 items-center justify-center rounded-full font-mono text-[16px] font-medium text-[var(--accent)]"
            style={{ background: "color-mix(in srgb, var(--accent) 12%, var(--surface-2))" }}
            aria-hidden
          >
            J
          </span>
          <span className="text-left">
            <span className="block text-[15px] font-semibold text-[var(--ink)]">Jae</span>
            <span className="block text-[13px] text-[var(--ink-faint)]">Builds Macaveli</span>
          </span>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Trust — three flat typographic cards (open source / private / native)
// ---------------------------------------------------------------------------

function Trust() {
  const cards: Array<{ tag: string; title: string; body: string }> = [
    {
      tag: "01 / open source",
      title: "Free & open source",
      body: "Macaveli is free forever, MIT-licensed, and built in the open on GitHub. Read the code, fork it, or send a pull request — there's no catch hiding behind a future paywall.",
    },
    {
      tag: "02 / private",
      title: "Private by design",
      body: "Clipboard history, screenshots, everything — it all stays on your Mac. No account, no telemetry, no analytics phoning home in the background.",
    },
    {
      tag: "03 / native",
      title: "Feels native",
      body: "About 14 MB, lives only in the menubar with no dock icon, and updates itself quietly in the background. It behaves like something Apple shipped, not something you installed.",
    },
  ];

  return (
    <section className="border-t border-[var(--line)] bg-[var(--surface-2)] px-8 py-28">
      <div className="mx-auto max-w-2xl text-center">
        <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // trust
        </p>
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(1.75rem, 4vw, 2.75rem)", lineHeight: 1.1 }}
        >
          Nothing to worry about.
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-[17px] leading-relaxed text-[var(--ink-muted)]">
          The parts you&rsquo;d normally have to take on faith, made obvious instead.
        </p>
      </div>

      <div className="mx-auto mt-14 grid max-w-5xl grid-cols-1 gap-6 md:grid-cols-3">
        {cards.map((card) => (
          <div
            key={card.tag}
            className="rounded-[11px] border border-[var(--line)] bg-[var(--surface)] p-8"
          >
            <p className="font-mono text-[12px] tracking-[0.02em] text-[var(--ink-faint)]">{card.tag}</p>
            <h3 className="mt-4 text-[19px] font-semibold text-[var(--ink)]">{card.title}</h3>
            <p className="mt-2 text-[14px] leading-[1.6] text-[var(--ink-muted)]">{card.body}</p>
          </div>
        ))}
      </div>

      <div className="mt-12 flex justify-center">
        <a
          href={REPO_URL}
          target="_blank"
          rel="noreferrer"
          className="rounded-full border border-[var(--line)] px-6 py-3 text-[14px] font-semibold text-[var(--ink)] transition hover:border-[var(--accent)] hover:text-[var(--accent)]"
        >
          View source on GitHub
        </a>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Big CTA
// ---------------------------------------------------------------------------

function CallToAction() {
  return (
    <section className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 py-32 text-center">
      <div className="mx-auto max-w-3xl">
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2.5rem, 6vw, 4.25rem)", lineHeight: 1.05 }}
        >
          Your Mac is already <span style={{ color: "var(--accent)" }}>ready</span>.
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-[19px] leading-[1.5] text-[var(--ink-muted)]">
          One install. No configuration. No account required.
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
            View on GitHub &rarr;
          </a>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// FAQ — native <details>, zero JS
// ---------------------------------------------------------------------------

function Faq() {
  const items: Array<[string, string]> = [
    [
      "Is it really free?",
      "Yes. Macaveli is free forever and open source under the MIT license. There's no trial, no paywall, and no plan to add one.",
    ],
    [
      "Why does it need Accessibility & Screen Recording permissions?",
      "Accessibility lets Macaveli move and resize windows on your behalf — that's what the window-control hotkeys actually do under the hood. Screen Recording is required by macOS for the screenshot and recording features, even though nothing is captured until you press the hotkey.",
    ],
    [
      "Does anything leave my Mac?",
      "No. Clipboard history, screenshots, and recordings all stay local. Macaveli has no telemetry and no analytics — there's nothing to send even if it wanted to.",
    ],
    [
      "Can I change the hotkeys?",
      "Every hotkey is rebindable from the menubar preferences, including the defaults for move, resize, screenshot, and the rest.",
    ],
    [
      "What macOS versions?",
      "macOS 13 (Ventura) and later, on Apple Silicon and Intel.",
    ],
    [
      "How do updates work?",
      "Macaveli checks for updates automatically and installs them via Sparkle, the same update framework used by many native Mac apps. No App Store, no manual downloads.",
    ],
  ];

  return (
    <section id="faq" className="border-t border-[var(--line)] bg-[var(--surface)] px-8 py-28">
      <div className="mx-auto max-w-2xl">
        <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
          // faq
        </p>
        <h2
          className="font-bold tracking-[-0.035em] text-[var(--ink)]"
          style={{ fontSize: "clamp(2rem, 5vw, 3rem)", lineHeight: 1.05 }}
        >
          We got answers.
        </h2>

        <div className="mt-14">
          {items.map(([question, answer]) => (
            <details key={question} className="group border-t border-[var(--line)] py-6">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-[16px] font-medium text-[var(--ink)] [&::-webkit-details-marker]:hidden">
                {question}
                <svg
                  className="shrink-0 transition-transform duration-200 ease-in-out group-open:rotate-180"
                  width="12"
                  height="12"
                  viewBox="0 0 12 12"
                  fill="none"
                  aria-hidden
                >
                  <path d="M2 4 L6 8 L10 4" stroke="var(--ink-faint)" strokeWidth="1.5" strokeLinecap="round" />
                </svg>
              </summary>
              <p className="mt-3 max-w-[62ch] text-[15px] leading-relaxed text-[var(--ink-muted)]">
                {answer}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Footer — link columns + the original legal strip as the bottom bar
// ---------------------------------------------------------------------------

function Footer() {
  return (
    <footer className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 pb-8 pt-16">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-10 md:grid-cols-4">
        <div className="col-span-2 md:col-span-1">
          <div className="flex items-center gap-2.5">
            <Logo />
            <span className="text-[15px] font-semibold tracking-tight">Macaveli</span>
          </div>
          <p className="mt-2 font-mono text-[12px] text-[var(--ink-faint)]">
            one install, your Mac is ready
          </p>
        </div>

        <div>
          <p className="font-mono text-[11px] uppercase tracking-[0.08em] text-[var(--ink-faint)]">
            Product
          </p>
          <div className="mt-3 space-y-2.5 text-[13px] text-[var(--ink-muted)]">
            <a href="#features" className="block transition hover:text-[var(--ink)]">
              Features
            </a>
            <a href="#faq" className="block transition hover:text-[var(--ink)]">
              FAQ
            </a>
            <a href="/changelog" className="block transition hover:text-[var(--ink)]">
              Changelog
            </a>
            <a href={DOWNLOAD_URL} className="block transition hover:text-[var(--ink)]">
              Download
            </a>
          </div>
        </div>

        <div>
          <p className="font-mono text-[11px] uppercase tracking-[0.08em] text-[var(--ink-faint)]">
            Resources
          </p>
          <div className="mt-3 space-y-2.5 text-[13px] text-[var(--ink-muted)]">
            <a href={REPO_URL} target="_blank" rel="noreferrer" className="block transition hover:text-[var(--ink)]">
              GitHub
            </a>
            <a href={`${REPO_URL}/issues`} target="_blank" rel="noreferrer" className="block transition hover:text-[var(--ink)]">
              Issues
            </a>
            <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="block transition hover:text-[var(--ink)]">
              Releases
            </a>
          </div>
        </div>

        <div className="space-y-2.5 font-mono text-[12px] text-[var(--ink-faint)]">
          <p>MIT licensed</p>
          <p>macOS 13+</p>
          <p>No telemetry</p>
        </div>
      </div>

      <div className="mx-auto mt-14 flex max-w-6xl flex-col items-center justify-between gap-4 border-t border-[var(--line)] pt-6 font-mono text-[12px] text-[var(--ink-faint)] sm:flex-row">
        <div className="flex items-center gap-2.5">
          <Logo size={16} className="text-[var(--ink-muted)]" />
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
