const RELEASES_URL = "https://github.com/jaequery/macaveli/releases/latest";
const REPO_URL = "https://github.com/jaequery/macaveli";

export default function Page() {
  return (
    <main className="min-h-screen bg-[#fafafa] text-zinc-900">
      <Nav />
      <Hero />
      <Pillars />
      <FounderNote />
      <Shortcuts />
      <CallToAction />
      <Footer />
    </main>
  );
}

function FounderNote() {
  return (
    <section className="border-t border-zinc-200 bg-[#fafafa] px-8 py-28">
      <div className="mx-auto max-w-2xl">
        <p className="mb-5 text-[13px] font-semibold uppercase tracking-[0.2em] text-zinc-500">
          Why it exists
        </p>
        <p className="text-[22px] leading-[1.45] text-zinc-800">
          I got a new MacBook and dreaded the next two hours — Rectangle,
          CleanShot, Loom, twelve more. Then I noticed I was reinstalling
          the same handful every time. The rest was noise.
        </p>
        <p className="mt-5 text-[19px] leading-[1.55] text-zinc-600">
          Macaveli is what's left when you keep only the essentials and put
          them in one place. Install it once. Skip the other twelve.
        </p>
        <p className="mt-8 text-[14px] font-medium text-zinc-500">
          — Jae, founder
        </p>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Nav
// ---------------------------------------------------------------------------

function Nav() {
  return (
    <nav className="mx-auto flex max-w-6xl items-center justify-between px-8 py-6">
      <a href="/" className="flex items-center gap-2.5">
        <Logo className="text-zinc-900" />
        <span className="text-[15px] font-semibold tracking-tight">
          Macaveli
        </span>
      </a>

      <div className="hidden gap-9 text-sm text-zinc-600 sm:flex">
        <a href="#features" className="transition hover:text-zinc-900">
          Overview
        </a>
        <a href="#shortcuts" className="transition hover:text-zinc-900">
          Shortcuts
        </a>
        <a
          href={REPO_URL}
          target="_blank"
          rel="noreferrer"
          className="transition hover:text-zinc-900"
        >
          GitHub
        </a>
      </div>

      <a
        href={RELEASES_URL}
        className="rounded-full bg-zinc-900 px-5 py-2 text-sm font-semibold text-white transition hover:bg-zinc-700"
      >
        Download
      </a>
    </nav>
  );
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

function Hero() {
  return (
    <section className="apple-wash">
      <div className="mx-auto max-w-6xl px-8 pb-32 pt-24 text-center">
        <p className="mb-5 text-[13px] font-semibold uppercase tracking-[0.2em] text-zinc-500">
          The Mac utility you forgot to install.
        </p>

        <h1
          className="font-bold tracking-[-0.04em] text-zinc-900"
          style={{ fontSize: "clamp(2.75rem, 7.5vw, 6rem)", lineHeight: 1 }}
        >
          One app.
          <br />
          Replace twelve.
        </h1>

        <p className="mx-auto mt-8 max-w-2xl text-pretty text-[22px] leading-[1.45] text-zinc-700">
          Window management, snap layouts, screen recording — every macOS
          utility you reinstall on a fresh Mac, in one tiny menubar app.
          Hold <Kbd>ctrl + cmd</Kbd>, drag anywhere. Done.
        </p>

        <p className="mx-auto mt-2 max-w-xl text-[17px] font-medium text-zinc-500">
          Free. Open source. No dock icon. No telemetry. No signup.
        </p>

        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={RELEASES_URL}
            className="rounded-full bg-zinc-900 px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-zinc-700"
          >
            Download for Mac
          </a>
          <a
            href="#features"
            className="text-[15px] font-semibold text-blue-600 transition hover:text-blue-700"
          >
            What it replaces →
          </a>
        </div>

        <ProductShowcase />
      </div>
    </section>
  );
}

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="rounded bg-zinc-200 px-1.5 py-0.5 font-mono text-[18px] text-zinc-800">
      {children}
    </kbd>
  );
}

// ---------------------------------------------------------------------------
// Product Showcase — stylized desktop with two snapped windows
// ---------------------------------------------------------------------------

function ProductShowcase() {
  return (
    <div className="mt-24">
      <div
        className="relative mx-auto aspect-[16/9] max-w-5xl overflow-hidden rounded-3xl shadow-[0_30px_80px_rgba(0,0,0,0.18)]"
        style={{
          background: "linear-gradient(180deg, #2b2b34 0%, #16161c 100%)",
        }}
      >
        {/* Fake macOS menubar */}
        <div className="absolute left-0 right-0 top-0 flex h-7 items-center gap-4 bg-white/[0.08] px-4 text-[11px] font-medium text-white/85 backdrop-blur">
          <AppleGlyph />
          <span className="font-semibold">Finder</span>
          <span>File</span>
          <span>Edit</span>
          <span>View</span>
          <div className="ml-auto flex items-center gap-3 text-white/70">
            {/* Macaveli's mark, in the menu bar — where it actually lives */}
            <Logo size={12} className="text-white/90" />
            <span>100%</span>
            <span>Wed 7:45 PM</span>
          </div>
        </div>

        {/* Two windows snapped to halves */}
        <DemoWindow side="left" accent="#67e8f9" />
        <DemoWindow side="right" accent="#f0abfc" />
      </div>
      <p className="mt-6 text-center text-[15px] text-zinc-500">
        Two windows. One keystroke each.{" "}
        <span className="rounded bg-zinc-200 px-1.5 py-0.5 font-mono text-[14px] text-zinc-800">
          ctrl + [
        </span>{" "}
        <span className="rounded bg-zinc-200 px-1.5 py-0.5 font-mono text-[14px] text-zinc-800">
          ctrl + ]
        </span>{" "}
        — done.
      </p>
    </div>
  );
}

function DemoWindow({
  side,
  accent,
}: {
  side: "left" | "right";
  accent: string;
}) {
  const pos = side === "left" ? "left-[3%]" : "right-[3%]";
  return (
    <div
      className={`absolute top-[12%] ${pos} flex h-[80%] w-[46%] flex-col overflow-hidden rounded-xl border border-white/10`}
      style={{
        background: "linear-gradient(180deg, #2c2c36 0%, #1c1c24 100%)",
        boxShadow: "0 20px 40px rgba(0,0,0,0.4)",
      }}
    >
      <div className="flex h-7 items-center gap-1.5 border-b border-white/5 bg-white/[0.04] px-3">
        <span className="h-2.5 w-2.5 rounded-full bg-[#ff5f57]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#febc2e]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#28c840]" />
      </div>
      <div className="flex-1 space-y-2.5 p-4">
        <div
          className="h-2 w-2/3 rounded"
          style={{ background: `${accent}66` }}
        />
        <div className="h-2 w-5/6 rounded bg-white/15" />
        <div className="h-2 w-4/5 rounded bg-white/15" />
        <div className="h-2 w-3/4 rounded bg-white/15" />
        <div className="h-2 w-2/3 rounded bg-white/15" />
        <div className="h-2 w-3/5 rounded bg-white/15" />
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Marketing pillars
// ---------------------------------------------------------------------------

function Pillars() {
  const items: Array<{
    eyebrow: string;
    title: string;
    body: string;
    replaces: string;
  }> = [
    {
      eyebrow: "Window management",
      title: "Move and resize from anywhere.",
      body: "Hold ctrl + cmd and drag any window from anywhere — no title bar, no corner-hunting. Snap to halves, maximize, re-center in one keystroke each. Quadrant-aware resize.",
      replaces: "Rectangle · Magnet · BetterTouchTool · Loop",
    },
    {
      eyebrow: "Screen recording",
      title: "Record from a hotkey.",
      body: "ctrl + cmd + R starts and stops a recording of your primary display. MP4 or MOV, optional ffmpeg optimization pass. No dialogs, no countdown nag, no upload.",
      replaces: "CleanShot X · Loom · Shottr · QuickTime",
    },
    {
      eyebrow: "Always on, never in the way",
      title: "Lives in the menu bar.",
      body: "No dock icon. No window cluttering your workspace. Open the popover the first week to learn the shortcuts. After that, forget it's installed.",
      replaces: "the urge to install five more menubar apps",
    },
  ];

  return (
    <section
      id="features"
      className="border-t border-zinc-200 bg-white px-8 py-32"
    >
      <div className="mx-auto max-w-6xl">
        <div className="mx-auto max-w-3xl text-center">
          <p className="mb-4 text-[13px] font-semibold uppercase tracking-[0.2em] text-zinc-500">
            What it replaces
          </p>
          <h2
            className="font-bold tracking-[-0.035em] text-zinc-900"
            style={{ fontSize: "clamp(2rem, 5vw, 3.5rem)", lineHeight: 1.05 }}
          >
            Three categories.
            <br />
            One menubar icon.
          </h2>
          <p className="mx-auto mt-5 max-w-xl text-[17px] leading-relaxed text-zinc-600">
            Everything below used to require a separate paid app. Macaveli does
            all of it, free, in 14 MB.
          </p>
        </div>

        <div className="mt-20 grid gap-10 sm:grid-cols-3">
          {items.map((item) => (
            <div
              key={item.eyebrow}
              className="rounded-2xl border border-zinc-200 bg-[#fafafa] p-7"
            >
              <p className="text-[12px] font-semibold uppercase tracking-[0.18em] text-zinc-500">
                {item.eyebrow}
              </p>
              <h3 className="mt-2 text-[22px] font-bold tracking-tight text-zinc-900">
                {item.title}
              </h3>
              <p className="mt-3 text-[16px] leading-[1.55] text-zinc-600">
                {item.body}
              </p>
              <div className="mt-5 border-t border-zinc-200 pt-4">
                <p className="text-[11px] font-semibold uppercase tracking-[0.14em] text-zinc-400">
                  Replaces
                </p>
                <p className="mt-1.5 text-[13px] font-medium text-zinc-700">
                  {item.replaces}
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
// Shortcuts — Apple-style spec table
// ---------------------------------------------------------------------------

function Shortcuts() {
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
    <section
      id="shortcuts"
      className="border-t border-zinc-200 bg-[#f4f4f5] px-8 py-32"
    >
      <div className="mx-auto max-w-3xl">
        <div className="text-center">
          <p className="mb-4 text-[13px] font-semibold uppercase tracking-[0.2em] text-zinc-500">
            Specifications
          </p>
          <h2
            className="font-bold tracking-[-0.035em] text-zinc-900"
            style={{ fontSize: "clamp(2rem, 5vw, 3.5rem)", lineHeight: 1.05 }}
          >
            Default shortcuts.
          </h2>
          <p className="mx-auto mt-4 max-w-md text-[17px] text-zinc-600">
            Every one of them is rebindable in the menu bar popover.
          </p>
        </div>

        <div className="mt-14 overflow-hidden rounded-2xl border border-zinc-200 bg-white">
          {rows.map(([keys, action], i) => (
            <div
              key={keys}
              className={`flex items-center justify-between gap-6 px-6 py-5 ${
                i !== 0 ? "border-t border-zinc-100" : ""
              }`}
            >
              <kbd className="rounded-md border border-zinc-200 bg-zinc-50 px-2.5 py-1 font-mono text-[13px] font-medium text-zinc-800">
                {keys}
              </kbd>
              <span className="text-right text-[15px] text-zinc-600">
                {action}
              </span>
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
    <section className="border-t border-zinc-200 bg-white px-8 py-32 text-center">
      <div className="mx-auto max-w-3xl">
        <h2
          className="font-bold tracking-[-0.035em] text-zinc-900"
          style={{ fontSize: "clamp(2rem, 5vw, 3.5rem)", lineHeight: 1.05 }}
        >
          Install it. Skip the other twelve.
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-[19px] leading-[1.5] text-zinc-600">
          14 MB. macOS 13+. Free, MIT-licensed, open source. No account, no
          telemetry, no upsell. Ever.
        </p>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
          <a
            href={RELEASES_URL}
            className="rounded-full bg-zinc-900 px-7 py-3.5 text-[15px] font-semibold text-white transition hover:bg-zinc-700"
          >
            Download for Mac
          </a>
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="text-[15px] font-semibold text-blue-600 hover:text-blue-700"
          >
            View source on GitHub →
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
    <footer className="border-t border-zinc-200 bg-[#fafafa] px-8 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 text-[12px] text-zinc-500 sm:flex-row">
        <div className="flex items-center gap-2.5">
          <Logo className="text-zinc-700" />
          <span>Macaveli · MIT-licensed · macOS 13+</span>
        </div>
        <div className="flex gap-6">
          <a
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            className="hover:text-zinc-900"
          >
            Source
          </a>
          <a
            href={`${REPO_URL}/issues`}
            target="_blank"
            rel="noreferrer"
            className="hover:text-zinc-900"
          >
            Issues
          </a>
          <a
            href={RELEASES_URL}
            target="_blank"
            rel="noreferrer"
            className="hover:text-zinc-900"
          >
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
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      aria-hidden
      className={className}
    >
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
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden
      className="text-white/85"
    >
      <path d="M17.05 12.04c-.02-2.18 1.78-3.23 1.86-3.28-1.01-1.48-2.59-1.68-3.15-1.7-1.34-.13-2.62.79-3.3.79-.68 0-1.74-.77-2.86-.75-1.47.02-2.83.85-3.59 2.17-1.53 2.65-.39 6.57 1.1 8.72.73 1.05 1.6 2.23 2.74 2.19 1.1-.05 1.51-.71 2.84-.71 1.33 0 1.7.71 2.86.69 1.18-.02 1.93-1.07 2.65-2.12.84-1.22 1.18-2.4 1.2-2.46-.03-.01-2.3-.88-2.35-3.54zM14.93 5.13c.6-.74 1.01-1.76.9-2.79-.87.04-1.94.59-2.56 1.32-.56.65-1.04 1.7-.91 2.7.97.08 1.97-.49 2.57-1.23z"/>
    </svg>
  );
}
