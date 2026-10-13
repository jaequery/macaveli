import type { Metadata } from "next";
import { DOWNLOAD_URL, DownloadIcon, Footer, Nav, RELEASES_URL, VERSION } from "../components/site";
import { releases, type Change, type ChangeType, type Release } from "./data";

export const metadata: Metadata = {
  title: "Changelog — Macaveli",
  description:
    "Every Macaveli release, newest first — new features, fixes, and improvements, organized by version and date.",
};

export default function ChangelogPage() {
  return (
    <>
      <Nav route="changelog" />
      <main id="main">
        <section className="cl-head">
          <div className="wrap">
            <p className="eyebrow">Changelog</p>
            <h1>What&rsquo;s new.</h1>
            <p className="lede">
              Every release, newest first. Macaveli updates itself — new features, fixes, and refinements
              land automatically.
            </p>
            <div className="ctas">
              <a className="pill" href={DOWNLOAD_URL}>
                <DownloadIcon />
                Download v{VERSION}
              </a>
              <a className="pill ghost" href={RELEASES_URL} target="_blank" rel="noreferrer">
                GitHub releases
              </a>
            </div>
          </div>
        </section>

        <section className="wrap">
          <div className="releases">
            {releases.map((release) => (
              <ReleaseCard key={release.version} release={release} />
            ))}
          </div>
        </section>
      </main>
      <Footer route="changelog" />
    </>
  );
}

// ---------------------------------------------------------------------------
// One release — a bento card: version/date left, grouped changes right.
// ---------------------------------------------------------------------------

const TYPE_ORDER: ChangeType[] = ["feature", "improvement", "fix"];

const TYPE_LABEL: Record<ChangeType, string> = {
  feature: "New",
  improvement: "Improved",
  fix: "Fixed",
};

function ReleaseCard({ release }: { release: Release }) {
  const grouped = TYPE_ORDER.map((type) => ({
    type,
    items: release.changes.filter((c) => c.type === type),
  })).filter((g) => g.items.length > 0);

  return (
    <article className="release" id={`v${release.version}`}>
      <div>
        <h2 className="ver">v{release.version}</h2>
        <time dateTime={release.date}>{formatDate(release.date)}</time>
        {release.version === VERSION && <span className="latest">latest</span>}
      </div>
      <div>
        {release.summary && <p className="summary">{release.summary}</p>}
        {grouped.map((group) => (
          <ChangeGroup key={group.type} type={group.type} items={group.items} />
        ))}
      </div>
    </article>
  );
}

function ChangeGroup({ type, items }: { type: ChangeType; items: Change[] }) {
  return (
    <div className={`cgroup ${type}`}>
      <h3>{TYPE_LABEL[type]}</h3>
      <ul>
        {items.map((item, i) => (
          <li key={i}>{item.text}</li>
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
