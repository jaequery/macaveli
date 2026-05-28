import type { Metadata } from "next";
import versionInfo from "../../version.json";
import { releases, type Change, type ChangeType } from "./data";

const VERSION = versionInfo.version;
const DOWNLOAD_URL = versionInfo.downloadUrl;
const RELEASES_URL = "https://github.com/jaequery/macaveli/releases/latest";
const REPO_URL = "https://github.com/jaequery/macaveli";

export const metadata: Metadata = {
  title: "Changelog — Macaveli",
  description:
    "Every Macaveli release, newest first — new features, fixes, and improvements, organized by version and date.",
};

export default function ChangelogPage() {
  return (
    <main className="min-h-screen bg-[var(--canvas)] text-[var(--ink)]">
      <Nav />
      <section className="px-8 pb-28 pt-16">
        <div className="mx-auto max-w-5xl">
          <p className="mb-4 font-mono text-[13px] font-medium tracking-[0.02em] text-[var(--accent)]">
            // changelog
          </p>
          <h1
            className="font-bold tracking-[-0.035em] text-[var(--ink)]"
            style={{ fontSize: "clamp(2rem, 5vw, 3.25rem)", lineHeight: 1.05 }}
          >
            What&rsquo;s new.
          </h1>
          <p className="mt-5 max-w-xl text-[17px] leading-relaxed text-[var(--ink-muted)]">
            Every release, newest first. Macaveli updates itself &mdash; new features,
            fixes, and refinements land automatically.
          </p>

          <div className="mt-16">
            {releases.map((release, i) => (
              <ReleaseRow key={release.version} release={release} isFirst={i === 0} />
            ))}
          </div>
        </div>
      </section>
      <Footer />
    </main>
  );
}

// ---------------------------------------------------------------------------
// One release — editorial two-column row (version/date left, changes right),
// mirroring the landing page's "What's inside" rhythm.
// ---------------------------------------------------------------------------

const TYPE_ORDER: ChangeType[] = ["feature", "improvement", "fix"];

const TYPE_LABEL: Record<ChangeType, string> = {
  feature: "New",
  improvement: "Improved",
  fix: "Fixed",
};

// Restrained semantic tint per DESIGN.md — color is rare and meaningful.
const TYPE_COLOR: Record<ChangeType, string> = {
  feature: "var(--accent)",
  improvement: "var(--warning)",
  fix: "var(--success)",
};

function ReleaseRow({ release, isFirst }: { release: (typeof releases)[number]; isFirst: boolean }) {
  const grouped = TYPE_ORDER.map((type) => ({
    type,
    items: release.changes.filter((c) => c.type === type),
  })).filter((g) => g.items.length > 0);

  return (
    <div
      className={`grid grid-cols-1 gap-x-12 gap-y-5 py-10 md:grid-cols-[220px_1fr] ${
        isFirst ? "" : "border-t border-[var(--line)]"
      }`}
    >
      <div>
        <p className="font-mono text-[15px] font-semibold tracking-tight text-[var(--ink)]">
          v{release.version}
        </p>
        <time
          dateTime={release.date}
          className="mt-1.5 block font-mono text-[12px] text-[var(--ink-faint)]"
        >
          {formatDate(release.date)}
        </time>
        {release.version === VERSION && (
          <span className="mt-3 inline-block rounded-full bg-[var(--cap-bg)] px-2.5 py-1 font-mono text-[10.5px] font-medium tracking-[0.04em] text-[var(--ink-muted)]">
            latest
          </span>
        )}
      </div>

      <div>
        {release.summary && (
          <p className="mb-5 text-[17px] leading-snug text-[var(--ink)]">{release.summary}</p>
        )}
        <div className="space-y-6">
          {grouped.map((group) => (
            <ChangeGroup key={group.type} type={group.type} items={group.items} />
          ))}
        </div>
      </div>
    </div>
  );
}

function ChangeGroup({ type, items }: { type: ChangeType; items: Change[] }) {
  return (
    <div>
      <p
        className="mb-2.5 flex items-center gap-2 font-mono text-[11px] font-medium uppercase tracking-[0.06em]"
        style={{ color: TYPE_COLOR[type] }}
      >
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: TYPE_COLOR[type] }} />
        {TYPE_LABEL[type]}
      </p>
      <ul className="space-y-2">
        {items.map((item, i) => (
          <li
            key={i}
            className="pl-[26px] text-[15px] leading-[1.55] text-[var(--ink-muted)]"
          >
            {item.text}
          </li>
        ))}
      </ul>
    </div>
  );
}

function formatDate(iso: string): string {
  // iso is yyyy-mm-dd; parse as UTC to avoid timezone drift.
  return new Date(`${iso}T00:00:00Z`).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });
}

// ---------------------------------------------------------------------------
// Chrome — matches the landing page but route-aware (links point back to `/`).
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
        <a href="/#inside" className="transition hover:text-[var(--ink)]">
          What&rsquo;s inside
        </a>
        <a href="/#shortcuts" className="transition hover:text-[var(--ink)]">
          Shortcuts
        </a>
        <a href="/changelog" className="text-[var(--ink)]">
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

function Footer() {
  return (
    <footer className="border-t border-[var(--line)] bg-[var(--canvas)] px-8 py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 font-mono text-[12px] text-[var(--ink-faint)] sm:flex-row">
        <div className="flex items-center gap-2.5">
          <Logo className="text-[var(--ink-muted)]" />
          <span>Macaveli · MIT · macOS 13+ · v{VERSION}</span>
        </div>
        <div className="flex gap-6">
          <a href="/" className="hover:text-[var(--ink)]">
            Home
          </a>
          <a href={REPO_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--ink)]">
            Source
          </a>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer" className="hover:text-[var(--ink)]">
            Releases
          </a>
        </div>
      </div>
    </footer>
  );
}

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
