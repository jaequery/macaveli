import versionInfo from "../../version.json";

// Shared chrome for every route — one nav, one footer, one set of primitives.
// `version.json` is rewritten by `make publish-web` on each release, so the
// version tag and download URL must always come from it.

export const VERSION = versionInfo.version;
export const DOWNLOAD_URL = versionInfo.downloadUrl;
export const REPO_URL = "https://github.com/jaequery/macaveli";
export const ISSUES_URL = `${REPO_URL}/issues`;
export const RELEASES_URL = `${REPO_URL}/releases/latest`;

type Route = "home" | "changelog";

// On the landing page, in-page anchors stay bare; elsewhere they route home.
function href(route: Route, hash: string) {
  return route === "home" ? hash : `/${hash}`;
}

export function Nav({ route }: { route: Route }) {
  return (
    <header className="nav" id="nav">
      <div className="wrap">
        <a href="/" className="logo" aria-label="Macaveli home">
          <Logo />
          Macaveli
          <span className="ver">v{VERSION}</span>
        </a>
        <nav className="navlinks" aria-label="Primary">
          <a href={href(route, "#features")}>Features</a>
          <a href="/changelog" aria-current={route === "changelog" ? "page" : undefined}>
            Changelog
          </a>
          <a href={href(route, "#faq")}>FAQ</a>
        </nav>
        <div className="navright">
          <a className="txt" href={REPO_URL} target="_blank" rel="noreferrer">
            GitHub
          </a>
          <a className="pill" href={DOWNLOAD_URL}>
            Download
          </a>
        </div>
      </div>
    </header>
  );
}

export function Footer({ route }: { route: Route }) {
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="foot">
          <div>
            <a href="/" className="logo">
              <Logo />
              Macaveli
            </a>
            <p>One install, your Mac is ready. Free and open source.</p>
          </div>
          <div>
            <h4>Product</h4>
            <ul>
              <li>
                <a href={href(route, "#features")}>Features</a>
              </li>
              <li>
                <a href={DOWNLOAD_URL}>Download</a>
              </li>
              <li>
                <a href="/changelog">Changelog</a>
              </li>
            </ul>
          </div>
          <div>
            <h4>Open source</h4>
            <ul>
              <li>
                <a href={REPO_URL} target="_blank" rel="noreferrer">
                  GitHub
                </a>
              </li>
              <li>
                <a href={ISSUES_URL} target="_blank" rel="noreferrer">
                  Issues
                </a>
              </li>
              <li>
                <a href={RELEASES_URL} target="_blank" rel="noreferrer">
                  Releases
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h4>Help</h4>
            <ul>
              <li>
                <a href={href(route, "#faq")}>FAQ</a>
              </li>
              <li>
                <a href={ISSUES_URL} target="_blank" rel="noreferrer">
                  Report a bug
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="legal">
          <span>Macaveli · MIT License · No telemetry</span>
          <span className="mono">v{VERSION} · macOS 13+ · Apple Silicon &amp; Intel</span>
        </div>
      </div>
    </footer>
  );
}

export function Logo() {
  return (
    <svg viewBox="0 0 32 32" aria-hidden>
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

export function DownloadIcon() {
  return (
    <svg viewBox="0 0 16 16" aria-hidden>
      <path
        d="M8 2v8.5M4.5 7 8 10.5 11.5 7M3 13.5h10"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/** A row of tactile keycaps, e.g. <Keys keys={["⌃", "⌘", "4"]} />. */
export function Keys({ keys, small = false, after }: { keys: string[]; small?: boolean; after?: string }) {
  return (
    <span className="combo">
      {keys.map((k) => (
        <kbd key={k} className={small ? "kc sm" : "kc"}>
          {k}
        </kbd>
      ))}
      {after && <span className="plus">{after}</span>}
    </span>
  );
}
