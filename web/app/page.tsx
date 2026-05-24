const RELEASES_URL = "https://github.com/jaequery/macaveli/releases/latest";
const REPO_URL = "https://github.com/jaequery/macaveli";

export default function Page() {
  return (
    <main className="min-h-screen">
      <Nav />
      <Hero />
      <Features />
      <Shortcuts />
      <Footer />
    </main>
  );
}

function Nav() {
  return (
    <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
      <a href="/" className="flex items-center gap-2 font-semibold tracking-tight">
        <Logo />
        <span>Macaveli</span>
      </a>
      <div className="flex items-center gap-6 text-sm text-[var(--color-fg-muted)]">
        <a href="#features" className="hover:text-[var(--color-fg)]">
          Features
        </a>
        <a href="#shortcuts" className="hover:text-[var(--color-fg)]">
          Shortcuts
        </a>
        <a
          href={REPO_URL}
          className="hover:text-[var(--color-fg)]"
          target="_blank"
          rel="noreferrer"
        >
          GitHub
        </a>
      </div>
    </nav>
  );
}

function Hero() {
  return (
    <section className="mx-auto max-w-6xl px-6 pt-20 pb-28 text-center">
      <p className="mb-5 inline-block rounded-full border border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-3 py-1 text-xs text-[var(--color-fg-muted)]">
        macOS · menubar app · open source
      </p>
      <h1 className="mx-auto max-w-3xl text-balance text-5xl font-semibold tracking-tight sm:text-6xl">
        Move, resize, and record macOS windows{" "}
        <span className="text-[var(--color-accent)]">from anywhere</span>.
      </h1>
      <p className="mx-auto mt-6 max-w-2xl text-pretty text-lg text-[var(--color-fg-muted)]">
        Hold a modifier. Drag anywhere on a window. Stop hunting for title bars
        and corners. Snap windows with one keystroke. Record your screen
        without leaving the menubar.
      </p>
      <div className="mt-10 flex items-center justify-center gap-3">
        <a
          href={RELEASES_URL}
          className="rounded-md bg-[var(--color-accent)] px-5 py-2.5 text-sm font-semibold text-[var(--color-bg)] transition hover:opacity-90"
        >
          Download for macOS
        </a>
        <a
          href={REPO_URL}
          className="rounded-md border border-[var(--color-border)] bg-[var(--color-bg-elevated)] px-5 py-2.5 text-sm font-semibold text-[var(--color-fg)] transition hover:border-[var(--color-fg-muted)]"
          target="_blank"
          rel="noreferrer"
        >
          View on GitHub
        </a>
      </div>
      <p className="mt-4 text-xs text-[var(--color-fg-muted)]">
        Free · auto-updates via Sparkle · requires macOS 13+
      </p>
    </section>
  );
}

function Features() {
  const items = [
    {
      title: "Modifier + drag to move",
      body: "Hold ⌃⌘ and drag anywhere on the window — no need to find the title bar. Works on full-screen apps that have no title bar at all.",
    },
    {
      title: "Modifier + drag to resize",
      body: "Hold ⌘⇧ and drag to resize. Quadrant mode is even smarter: corners pin the opposite corner, edges resize one axis, the middle resizes symmetrically.",
    },
    {
      title: "Snap to halves with one key",
      body: "⌃[ snaps the focused window to the left half. ⌃] snaps to the right. ⌃⌘↑ maximizes. ⌃⌘↓ centers. All rebindable.",
    },
    {
      title: "Record from the menubar",
      body: "Hit ⌃⌘R to start recording the primary display. MP4 or MOV, optional optimization pass with ffmpeg. No dialogs in your way.",
    },
    {
      title: "Just lives in the menubar",
      body: "No dock icon, no window cluttering your workspace. One tiny menubar icon. Open settings only when you actually need to.",
    },
    {
      title: "Auto-updates, signed",
      body: "Sparkle-powered updates with EdDSA signatures. New versions show up; you click install. No manual downloads after the first.",
    },
  ];

  return (
    <section
      id="features"
      className="mx-auto max-w-6xl px-6 py-20"
    >
      <h2 className="mb-12 text-center text-3xl font-semibold tracking-tight sm:text-4xl">
        Built for people who use keyboard shortcuts unironically.
      </h2>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {items.map((item) => (
          <div
            key={item.title}
            className="rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)] p-6 transition hover:border-[var(--color-fg-muted)]"
          >
            <h3 className="mb-2 text-base font-semibold">{item.title}</h3>
            <p className="text-sm text-[var(--color-fg-muted)]">{item.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function Shortcuts() {
  const rows: Array<[string, string]> = [
    ["⌃⌘ + drag", "Move the window under the cursor"],
    ["⌘⇧ + drag", "Resize the window under the cursor"],
    ["⌃[", "Snap focused window to left half"],
    ["⌃]", "Snap focused window to right half"],
    ["⌃⌘↑", "Maximize focused window"],
    ["⌃⌘↓", "Center focused window at 60%"],
    ["⌃⌘R", "Start / stop screen recording"],
  ];

  return (
    <section id="shortcuts" className="mx-auto max-w-3xl px-6 py-20">
      <h2 className="mb-2 text-center text-3xl font-semibold tracking-tight sm:text-4xl">
        Default shortcuts
      </h2>
      <p className="mb-10 text-center text-sm text-[var(--color-fg-muted)]">
        Every shortcut is rebindable in Preferences.
      </p>
      <div className="overflow-hidden rounded-xl border border-[var(--color-border)] bg-[var(--color-bg-elevated)]">
        {rows.map(([keys, action], i) => (
          <div
            key={keys}
            className={`flex items-center justify-between px-5 py-3 text-sm ${
              i !== 0 ? "border-t border-[var(--color-border)]" : ""
            }`}
          >
            <kbd className="rounded-md border border-[var(--color-border)] bg-[var(--color-bg)] px-2.5 py-1 font-mono text-[13px] text-[var(--color-fg)]">
              {keys}
            </kbd>
            <span className="text-[var(--color-fg-muted)]">{action}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="mx-auto max-w-6xl px-6 py-12">
      <div className="flex flex-col items-center justify-between gap-4 border-t border-[var(--color-border)] pt-8 text-sm text-[var(--color-fg-muted)] sm:flex-row">
        <span>
          © {new Date().getFullYear()} Macaveli. MIT-licensed, open source.
        </span>
        <div className="flex gap-5">
          <a href={REPO_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--color-fg)]">
            Source
          </a>
          <a
            href={`${REPO_URL}/issues`}
            target="_blank"
            rel="noreferrer"
            className="hover:text-[var(--color-fg)]"
          >
            Report a bug
          </a>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--color-fg)]">
            Releases
          </a>
        </div>
      </div>
    </footer>
  );
}

function Logo() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden
    >
      <rect
        x="3"
        y="6"
        width="26"
        height="20"
        rx="3"
        stroke="currentColor"
        strokeWidth="2"
      />
      <line
        x1="3"
        y1="16"
        x2="29"
        y2="16"
        stroke="currentColor"
        strokeWidth="2"
      />
      <line
        x1="16"
        y1="16"
        x2="16"
        y2="26"
        stroke="currentColor"
        strokeWidth="2"
      />
    </svg>
  );
}
