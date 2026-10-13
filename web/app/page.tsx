import { DOWNLOAD_URL, DownloadIcon, Footer, Keys, Logo, Nav, RELEASES_URL, REPO_URL, VERSION } from "./components/site";

// Landing page. Section flow from "Bento Tactile" (creatorspace.co-style),
// restyled after shiori.sh (DESIGN.md): hero + framed preview → hotkey marquee →
// value line → fact strip → feature bento → numbered list + orbit → statement
// + stats → banner → three tall cards → four blocks + founder → FAQ → final
// CTA → footer. Every visual is CSS/SVG (no images, no layout shift); every
// claim comes from the app itself.

export default function Page() {
  return (
    <>
      <Nav route="home" />
      <main id="main">
        <Hero />
        <HotkeyMarquee />
        <Value />
        <Facts />
        <Features />
        <WindowControl />
        <Stats />
        <Banner />
        <Capture />
        <Principles />
        <Faq />
        <FinalCta />
      </main>
      <Footer route="home" />
    </>
  );
}

// ---------------------------------------------------------------------------
// Hero — shiori-style left-aligned copy (mark → headline → gray subhead → CTAs),
// then a framed preview holding the big tactile ⌃ ⌘ ⇧ caps (they sink on hover,
// or when you hold the real keys) with floating window + chip objects.
// ---------------------------------------------------------------------------

function Hero() {
  return (
    <section className="hero">
      <div className="wrap hero-copy">
        <a href="/" className="hero-mark" aria-label="Macaveli home">
          <Logo />
        </a>
        <div className="hero-text">
          <h1>Your Mac, already set up.</h1>
          <p>
            Macaveli is one free menubar app with the window, capture and clipboard tools everyone
            installs on a new Mac. Pre-bound hotkeys. Zero config.
          </p>
        </div>
        <div className="ctas">
          <a className="pill lg" href={DOWNLOAD_URL}>
            <DownloadIcon />
            Download for Mac
          </a>
          <a className="pill lg ghost" href="#features">
            See the hotkeys
          </a>
        </div>
        <p className="meta">v{VERSION} · free · MIT · macOS 13+ · ~14 MB</p>
      </div>

      <div className="wrap preview-wrap">
        <div className="preview">
          <div className="preview-bar" aria-hidden>
            <Dots />
            <span>Macaveli</span>
          </div>
          <div className="stage" aria-hidden>
            <div className="tilt">
              <div className="capfloat" style={{ left: "calc(50% - 150px)", top: 20 }}>
                <span className="bigcap" data-key="Control" style={{ "--w": "124px" } as React.CSSProperties}>
                  <span>⌃</span>
                  <small>control</small>
                </span>
              </div>
              <div className="capfloat" style={{ left: "calc(50% + 26px)", top: 20 }}>
                <span className="bigcap" data-key="Meta" style={{ "--w": "124px" } as React.CSSProperties}>
                  <span>⌘</span>
                  <small>command</small>
                </span>
              </div>
              <div className="capfloat" style={{ left: "calc(50% + 196px)", top: 110 }}>
                <span className="bigcap" data-key="Shift" style={{ "--w": "76px" } as React.CSSProperties}>
                  <span>⇧</span>
                </span>
              </div>
            </div>
            <span className="plus-big">+</span>

            <div className="mini" style={{ left: -60, top: 30, width: 150, animationDelay: "-3s" }}>
              <div className="bar">
                <Dots />
              </div>
              <div className="body">
                <Line w="80%" />
                <Line w="55%" />
                <Line w="68%" />
              </div>
            </div>
            <div className="mini" style={{ right: -80, top: -6, width: 120, animationDelay: "-6s" }}>
              <div className="bar">
                <Dots />
              </div>
              <div className="body">
                <Line w="70%" />
                <Line w="44%" />
              </div>
            </div>
            <span className="chip" style={{ left: -10, top: 180, animationDelay: "-1s" }}>
              <span className="sw" />
              #F472B6
            </span>
            <span className="chip" style={{ right: -40, top: 200, animationDelay: "-5s" }}>
              <span className="rec" />
              REC 00:12
            </span>
            <span className="hint">psst — hold ⌃ ⌘ on your keyboard</span>
          </div>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Hotkey marquee — the creator-card rows, recast as the 11 pre-bound hotkeys.
// Rendered on the server; the duplicate half exists only for the seamless loop.
// ---------------------------------------------------------------------------

type Hotkey = { icon: keyof typeof ICONS; name: string; hint: string; keys: string[]; after?: string };

const HOTKEYS: Hotkey[] = [
  { icon: "move", name: "Move window", hint: "grab anywhere", keys: ["⌃", "⌘"], after: "+drag" },
  { icon: "resize", name: "Resize window", hint: "knows where you grabbed", keys: ["⌘", "⇧"], after: "+drag" },
  { icon: "half", name: "Left half", hint: "snap", keys: ["⌃", "["] },
  { icon: "half", name: "Right half", hint: "snap", keys: ["⌃", "]"] },
  { icon: "max", name: "Maximize", hint: "fill the screen", keys: ["⌃", "⌘", "↑"] },
  { icon: "center", name: "Center", hint: "bring it home", keys: ["⌃", "⌘", "↓"] },
  { icon: "shot", name: "Screenshot", hint: "region → clipboard", keys: ["⌃", "⌘", "4"] },
  { icon: "pen", name: "Annotate", hint: "arrows, text, shapes", keys: ["⌃", "⌘", "A"] },
  { icon: "drop", name: "Eyedropper", hint: "hex copied", keys: ["⌃", "⌘", "E"] },
  { icon: "clip", name: "Clipboard", hint: "text + images", keys: ["⌃", "⌘", "P"] },
  { icon: "rec", name: "Record", hint: "MP4 or GIF", keys: ["⌃", "⌘", "R"] },
];

const ICONS = {
  move: (
    <path d="M10 2v16M2 10h16M10 2 7.5 4.5M10 2l2.5 2.5M10 18l-2.5-2.5M10 18l2.5-2.5M2 10l2.5-2.5M2 10l2.5 2.5M18 10l-2.5-2.5M18 10l-2.5 2.5" />
  ),
  resize: <path d="M4 16 16 4M16 4h-5M16 4v5M4 16h5M4 16v-5" />,
  half: (
    <>
      <rect x="2.5" y="3.5" width="15" height="13" rx="2" />
      <path d="M10 3.5v13" />
    </>
  ),
  max: (
    <>
      <rect x="2.5" y="3.5" width="15" height="13" rx="2" />
      <path d="M7 8l3-3 3 3" />
    </>
  ),
  center: (
    <>
      <rect x="2.5" y="3.5" width="15" height="13" rx="2" />
      <rect x="6.5" y="7" width="7" height="6" rx="1" />
    </>
  ),
  shot: (
    <>
      <path d="M3 7V4h3M14 4h3v3M17 13v3h-3M6 16H3v-3" />
      <circle cx="10" cy="10" r="2.5" />
    </>
  ),
  pen: <path d="M3 17l3.5-1L16 6.5 13.5 4 4 13.5z" />,
  drop: (
    <>
      <path d="M12 4l4 4-8 8H4v-4z" />
      <path d="M11 5l4 4" />
    </>
  ),
  clip: (
    <>
      <rect x="4.5" y="3.5" width="11" height="14" rx="2" />
      <path d="M7.5 3.5h5v2h-5z" />
    </>
  ),
  rec: (
    <>
      <circle cx="10" cy="10" r="7" />
      <circle cx="10" cy="10" r="3" fill="#FF3B30" stroke="none" />
    </>
  ),
};

function HotkeyCard({ h }: { h: Hotkey }) {
  return (
    <div className="hk press">
      <span className="ic">
        <svg viewBox="0 0 20 20" aria-hidden>
          {ICONS[h.icon]}
        </svg>
      </span>
      <span>
        <b>{h.name}</b>
        <em>{h.hint}</em>
      </span>
      <Keys keys={h.keys} small after={h.after} />
    </div>
  );
}

/** A seamless marquee: the items, then an aria-hidden copy for the loop. */
function Loop({ children, className = "track" }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={className}>
      {children}
      <div aria-hidden style={{ display: "contents" }}>
        {children}
      </div>
    </div>
  );
}

function HotkeyMarquee() {
  const rowA = HOTKEYS.slice(0, 6);
  const rowB = [...HOTKEYS.slice(6), ...HOTKEYS.slice(0, 2)];
  return (
    <section className="marq" aria-label="Pre-bound hotkeys">
      <Loop>
        {rowA.map((h) => (
          <HotkeyCard key={h.name} h={h} />
        ))}
      </Loop>
      <div aria-hidden>
        <Loop className="track r2">
          {rowB.map((h) => (
            <HotkeyCard key={h.name} h={h} />
          ))}
        </Loop>
      </div>
    </section>
  );
}

function Value() {
  return (
    <section className="value">
      <div className="wrap rv">
        <p>
          Stop rebuilding your setup from a list.{" "}
          <span>
            Install one app and the shortcuts are already there — window moves, snaps, screenshots,
            clipboard history, recording.
          </span>
        </p>
      </div>
    </section>
  );
}

// The "trusted by" logo strip, without borrowed logos: plain facts instead.
function Facts() {
  const facts = [
    "Free forever",
    "MIT licensed",
    "No account",
    "No telemetry",
    "Everything stays local",
    "~14 MB",
    "Menubar only",
    "macOS 13 Ventura+",
    "Apple Silicon & Intel",
    "Sparkle auto-updates",
  ];
  return (
    <div className="facts" aria-label="At a glance">
      <Loop>
        {facts.map((f) => (
          <span key={f} className="fact">
            {f}
          </span>
        ))}
      </Loop>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Feature bento — one white card per tool, each with its keycaps + a mini mock.
// ---------------------------------------------------------------------------

function Features() {
  return (
    <section className="sec" id="features">
      <div className="wrap">
        <div className="sechead rv">
          <div>
            <p className="eyebrow">Features</p>
            <h2 className="h2">
              Every tool, one press away.
            </h2>
          </div>
          <p className="lede">
            Eleven hotkeys come pre-bound, configured before you ever open the app. Every one of them is
            rebindable from the menubar.
          </p>
        </div>

        <div className="bento rv">
          <article className="card b-move press rv">
            <div className="top">
              <span className="tag">Window · move &amp; resize</span>
              <Keys keys={["⌃", "⌘"]} after="+ drag" />
            </div>
            <div className="mock tall-1" aria-hidden>
              <div className="mv-ghost" />
              <div className="win mv-win">
                <div className="bar">
                  <Dots />
                </div>
                <div className="body">
                  <Line w="70%" />
                  <Line w="50%" />
                  <Line w="62%" />
                </div>
                <Cursor className="cursor mv-cur" />
              </div>
              <span className="resize-note">
                <Keys keys={["⌘", "⇧"]} small /> + drag resizes
              </span>
            </div>
            <h3>Grab a window anywhere.</h3>
            <p>
              Hold ⌃⌘ and drag from any point — not just the title bar. Hold ⌘⇧ to resize: grab a corner
              and that corner moves; grab the middle and it grows evenly from the center.
            </p>
          </article>

          <article className="card b-snap press rv">
            <div className="top">
              <span className="tag">Snap</span>
              <Keys keys={["⌃", "["]} />
            </div>
            <div className="mock" aria-hidden>
              <div className="snap-grid">
                <div className="on">
                  <kbd className="kc sm">[</kbd>
                </div>
                <div>
                  <kbd className="kc sm">]</kbd>
                </div>
              </div>
            </div>
            <h3>Halves, max, center.</h3>
            <p>⌃[ left · ⌃] right · ⌃⌘↑ maximize · ⌃⌘↓ center.</p>
          </article>

          <article className="card b-shot press rv">
            <div className="top">
              <span className="tag">Screenshot</span>
              <Keys keys={["⌃", "⌘", "4"]} />
            </div>
            <div className="mock" aria-hidden>
              <div className="sel" />
              <div className="toast">
                <i>✓</i>Copied to clipboard
              </div>
            </div>
            <h3>Region to clipboard.</h3>
            <p>Drag a region; it lands on your clipboard with a quick confirmation.</p>
          </article>

          <article className="card b-ann press rv">
            <div className="top">
              <span className="tag">Annotate</span>
              <Keys keys={["⌃", "⌘", "A"]} />
            </div>
            <div className="mock" aria-hidden>
              <svg className="annot" viewBox="0 0 200 150">
                <rect className="paper" x="22" y="22" width="156" height="106" rx="8" />
                <rect className="ln-fill" x="40" y="40" width="70" height="5" rx="2.5" />
                <rect className="ln-fill" x="40" y="52" width="50" height="5" rx="2.5" />
                <rect x="104" y="68" width="58" height="40" rx="4" fill="none" stroke="var(--accent)" strokeWidth="2.2" />
                <path d="M52 108 L96 84" stroke="var(--pink)" strokeWidth="3" strokeLinecap="round" />
                <path
                  d="M86 82 L97 83.5 L92 93"
                  fill="none"
                  stroke="var(--pink)"
                  strokeWidth="3"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <text x="40" y="122" fontSize="10">
                  fix this
                </text>
                <rect className="handle" x="101" y="65" width="6" height="6" stroke="var(--accent)" strokeWidth="1.4" />
                <rect className="handle" x="159" y="105" width="6" height="6" stroke="var(--accent)" strokeWidth="1.4" />
              </svg>
            </div>
            <h3>Mark it up.</h3>
            <p>Arrows, text and shapes on the clipboard image — each one selectable, movable, resizable.</p>
          </article>

          <article className="card b-eye press rv">
            <div className="top">
              <span className="tag">Eyedropper</span>
              <Keys keys={["⌃", "⌘", "E"]} />
            </div>
            <div className="mock" aria-hidden>
              <div className="loupe" />
              <div className="hex">
                <span className="sw" />
                #F472B6 copied
              </div>
            </div>
            <h3>Any pixel, as hex.</h3>
            <p>Sample a color anywhere on screen; the hex code is copied.</p>
          </article>

          <article className="card b-clip press rv">
            <div className="top">
              <span className="tag">Clipboard history</span>
              <Keys keys={["⌃", "⌘", "P"]} />
            </div>
            <div className="mock tall-2" aria-hidden>
              <div className="clipl">
                <div className="row on">
                  <span className="thumb" />
                  Screenshot 2:14 PM<span className="lbl">mockup</span>
                </div>
                <div className="row">
                  <span className="mono" style={{ fontSize: 11 }}>
                    git
                  </span>
                  git push origin main
                </div>
                <div className="row">
                  <span className="thumb warm" />
                  Image · 1440 × 900
                </div>
                <div className="row">
                  github.com/jaequery/macaveli<span className="lbl">repo</span>
                </div>
              </div>
            </div>
            <h3>Everything you copied.</h3>
            <p>Text and images with thumbnails, custom labels and image zoom. History stays on your Mac.</p>
          </article>

          <article className="card b-rec press rv">
            <div className="top">
              <span className="tag">Screen recording</span>
              <Keys keys={["⌃", "⌘", "R"]} />
            </div>
            <div className="mock tall-2" aria-hidden>
              <div className="hud">
                <span className="rec" />
                00:12 · system audio + mic
              </div>
              <div className="fmt">
                <span>MP4</span>
                <span>GIF</span>
              </div>
              <div className="cam" />
            </div>
            <h3>Press, record, press.</h3>
            <p>
              No countdown, no watermark, no upload. MP4 or GIF, a draggable camera overlay, system audio
              and microphone.
            </p>
          </article>

          <article className="card b-sleep rv">
            <div className="top">
              <span className="tag">Never Sleep</span>
              <span className="note">menubar</span>
            </div>
            <div className="seg" aria-hidden>
              <div>Off</div>
              <div>While lid open</div>
              <div className="on">
                Even lid closed <small>AC only</small>
              </div>
            </div>
            <h3>Stay awake, safely.</h3>
            <p>Lid-closed mode only arms on AC power, and a tiny watchdog turns it off the instant you unplug.</p>
          </article>

          <article className="card b-key rv">
            <div className="top">
              <span className="tag">Key Repeat</span>
              <span className="fastbtn">Fast</span>
            </div>
            <div className="slider" aria-hidden>
              <div className="rail">
                <div className="fill" />
                <div className="sys" />
                <div className="knob" />
              </div>
              <div className="scale">
                <span>slow</span>
                <span>System max</span>
                <span>faster</span>
              </div>
            </div>
            <h3>Faster than Settings.</h3>
            <p>Key repeat past what System Settings allows, with a one-tap Fast preset.</p>
          </article>

          <article className="card b-remote rv">
            <div className="top">
              <span className="tag">Remote</span>
              <span className="note">Bonjour</span>
            </div>
            <div className="macs" aria-hidden>
              <div>
                <MacIcon />
                Studio Mac<small>nearby</small>
              </div>
              <div>
                <MacIcon />
                office.local<small>saved</small>
              </div>
            </div>
            <h3>Your other Macs.</h3>
            <p>
              Find Macs on your network and open them in Apple&rsquo;s Screen Sharing. No relay — use
              Tailscale to reach them from anywhere.
            </p>
          </article>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Window control — numbered list + an orbit of snap positions around a window.
// ---------------------------------------------------------------------------

const ORBIT: Array<[label: string, keys: string, area: React.CSSProperties]> = [
  ["Left half", "⌃[", { left: "6%", top: "12%", width: "42%", height: "76%" }],
  ["Right half", "⌃]", { left: "52%", top: "12%", width: "42%", height: "76%" }],
  ["Maximize", "⌃⌘↑", { left: "6%", top: "12%", width: "88%", height: "76%" }],
  ["Center", "⌃⌘↓", { left: "25%", top: "22%", width: "50%", height: "56%" }],
  ["Move", "⌃⌘ drag", { left: "44%", top: "30%", width: "44%", height: "50%" }],
  ["Resize", "⌘⇧ drag", { left: "10%", top: "18%", width: "62%", height: "64%" }],
];

function WindowControl() {
  return (
    <section className="sec">
      <div className="wrap orbit-sec">
        <div className="rv">
          <p className="eyebrow">Window control</p>
          <h2 className="h2">
            Put any window where it belongs.
          </h2>
          <ol className="nlist">
            <li>
              <span className="n">01</span>
              <div>
                <b>Point at it</b>
                <span>Macaveli targets the window under your cursor. No clicking to focus first.</span>
              </div>
            </li>
            <li>
              <span className="n">02</span>
              <div>
                <b>Hold ⌃⌘ and drag</b>
                <span>Move from anywhere inside the window, not just the title bar.</span>
              </div>
            </li>
            <li>
              <span className="n">03</span>
              <div>
                <b>Hold ⌘⇧ to resize</b>
                <span>Where you grab decides what changes — corner, edge, or evenly from the center.</span>
              </div>
            </li>
            <li>
              <span className="n">04</span>
              <div>
                <b>Or snap it</b>
                <span>⌃[ and ⌃] for halves, ⌃⌘↑ to maximize, ⌃⌘↓ to center.</span>
              </div>
            </li>
          </ol>
        </div>

        <div className="orbit rv" aria-hidden>
          <div className="rings" />
          <div className="center">
            <div className="bar">
              <Dots />
            </div>
            <div className="body">
              <Line w="76%" />
              <Line w="52%" />
              <Line w="64%" />
              <Line w="40%" />
            </div>
          </div>
          <div className="spin">
            {ORBIT.map(([label, keys, area], i) => {
              const t = (i / ORBIT.length) * Math.PI * 2 - Math.PI / 2;
              const x = (50 + 50 * Math.cos(t)).toFixed(2);
              const y = (50 + 50 * Math.sin(t)).toFixed(2);
              return (
                <div key={label} className="orb" style={{ left: `${x}%`, top: `${y}%` }}>
                  <div>
                    <div className="pos">
                      <span className="mini-scr">
                        <i style={area} />
                      </span>
                      <small>{label}</small>
                      <kbd className="kc sm">{keys}</kbd>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}

function Stats() {
  return (
    <section className="sec statement">
      <div className="wrap">
        <h2 className="h2 rv">One install. Your Mac is ready.</h2>
        <a className="pill lg" href={DOWNLOAD_URL}>
          <DownloadIcon />
          Download free
        </a>
        <ul className="stats rv">
          <li className="stat rv">
            <div className="num">11</div>
            <p>pre-bound hotkeys, all rebindable</p>
          </li>
          <li className="stat rv">
            <div className="num">
              <sup>$</sup>0
            </div>
            <p>free forever, MIT licensed</p>
          </li>
          <li className="stat rv">
            <div className="num">0</div>
            <p>telemetry, analytics or accounts</p>
          </li>
          <li className="stat rv">
            <div className="num">
              <sup>~</sup>14<span className="unit"> MB</span>
            </div>
            <p>menubar only, no Dock icon</p>
          </li>
        </ul>
      </div>
    </section>
  );
}

function Banner() {
  return (
    <section className="banner" aria-label="One install. Your Mac is ready.">
      <div aria-hidden>
        <Loop>
          <span>One install</span>
          <span className="k">Your Mac is ready</span>
          <span>One install</span>
          <span className="k">Your Mac is ready</span>
        </Loop>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Capture — the three tall "pitch" cards, each with Hotkey / Output fields.
// ---------------------------------------------------------------------------

function Capture() {
  return (
    <section className="sec">
      <div className="wrap">
        <div className="sechead rv">
          <div>
            <p className="eyebrow">Capture</p>
            <h2 className="h2">
              Show, copy, record.
            </h2>
          </div>
          <p className="lede">
            Three tools you&rsquo;d otherwise install separately — built in, bound, and local.
          </p>
        </div>
        <div className="tall">
          <article className="tc press rv">
            <div className="thumb-l" aria-hidden>
              <div className="shot-paper">
                <div className="sel" />
              </div>
              <Keys keys={["⌃", "⌘", "4"]} />
            </div>
            <h3>Capture</h3>
            <p>Drag a region, then mark it up with ⌃⌘A.</p>
            <Fields hotkey="⌃⌘4" output="Clipboard" />
          </article>
          <article className="tc press rv">
            <div className="thumb-l" aria-hidden>
              <div className="clip-stack">
                <div className="on">
                  <span className="thumb" />
                  <Line w="100%" />
                </div>
                <div>
                  <Line w="70%" />
                </div>
                <div>
                  <Line w="50%" />
                </div>
              </div>
              <Keys keys={["⌃", "⌘", "P"]} />
            </div>
            <h3>Clipboard</h3>
            <p>Text and images, with thumbnails and labels you can find at a glance.</p>
            <Fields hotkey="⌃⌘P" output="Stays local" />
          </article>
          <article className="tc press rv">
            <div className="thumb-l" aria-hidden>
              <div className="hud static">
                <span className="rec" />
                00:12
              </div>
              <Keys keys={["⌃", "⌘", "R"]} />
            </div>
            <h3>Record</h3>
            <p>Start and stop with one hotkey. Nothing is uploaded.</p>
            <Fields hotkey="⌃⌘R" output="MP4 or GIF" />
          </article>
        </div>
      </div>
    </section>
  );
}

function Fields({ hotkey, output }: { hotkey: string; output: string }) {
  return (
    <dl className="fields">
      <div>
        <dt>Hotkey</dt>
        <dd className="mono">{hotkey}</dd>
      </div>
      <div>
        <dt>Output</dt>
        <dd>{output}</dd>
      </div>
    </dl>
  );
}

// ---------------------------------------------------------------------------
// Principles + founder note (the testimonial slot, used honestly).
// ---------------------------------------------------------------------------

function Principles() {
  return (
    <section className="sec">
      <div className="wrap">
        <div className="four">
          <div className="rv">
            <div className="k" aria-hidden>
              <kbd className="kc">$0</kbd>
            </div>
            <h3>Free, for real</h3>
            <p>MIT-licensed and open source. No paywall, no account, no signup.</p>
          </div>
          <div className="rv">
            <div className="k" aria-hidden>
              <kbd className="kc">⌂</kbd>
            </div>
            <h3>Stays on your Mac</h3>
            <p>No telemetry, no analytics. Your clipboard and captures never leave.</p>
          </div>
          <div className="rv">
            <div className="k" aria-hidden>
              <kbd className="kc">≡</kbd>
            </div>
            <h3>Lives in the menubar</h3>
            <p>No Dock icon, no window to manage. About 14 MB.</p>
          </div>
          <div className="rv">
            <div className="k" aria-hidden>
              <kbd className="kc">↻</kbd>
            </div>
            <h3>Updates itself</h3>
            <p>Sparkle keeps it current. macOS 13+, Apple Silicon and Intel.</p>
          </div>
        </div>

        <figure className="founder rv">
          <div className="avatar" aria-hidden>
            J
          </div>
          <div>
            <blockquote>
              <p>
                &ldquo;I got a new MacBook and did what I always do: started listing everything I&rsquo;d
                need to install and configure before it felt like mine. About an hour in, I realized I was
                rebuilding the same afternoon I&rsquo;d already lost the last time.
              </p>
              <p>
                So I stopped listing and started building — one menubar app with sane defaults for the stuff
                every Mac needs, ready the moment you install it.&rdquo;
              </p>
            </blockquote>
            <figcaption>Jae — builds Macaveli</figcaption>
          </div>
        </figure>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// FAQ — native <details>, works without JS.
// ---------------------------------------------------------------------------

const FAQ: Array<[string, string]> = [
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
    "No. Clipboard history, screenshots, and recordings all stay local. Macaveli has no account, no telemetry and no analytics.",
  ],
  [
    "Can I change the hotkeys?",
    "Yes, every one. All eleven come pre-bound so it works out of the box, and each is rebindable from the menubar preferences.",
  ],
  ["What macOS versions?", "macOS 13 (Ventura) and later, on Apple Silicon and Intel."],
  [
    "How do updates work?",
    "Macaveli checks for updates automatically and installs them via Sparkle, the update framework used by many native Mac apps. No App Store, no manual downloads. Every release is listed in the changelog.",
  ],
  ["Will it add a Dock icon?", "No. Macaveli lives in the menubar only."],
  [
    "Can I reach my other Macs over the internet?",
    "Remote finds Macs on your local network and opens them in Apple's Screen Sharing. To reach them from elsewhere, use your own network path such as Tailscale — there's no Macaveli relay.",
  ],
  ["Where is the source?", "On GitHub at jaequery/macaveli. Issues and pull requests are welcome."],
];

function Faq() {
  return (
    <section className="sec" id="faq">
      <div className="wrap faq">
        <h2 className="h2 rv">Questions, answered.</h2>
        <div className="qs">
          {FAQ.map(([q, a]) => (
            <details key={q} className="q">
              <summary>
                {q}
                <span className="tg" aria-hidden>
                  <svg viewBox="0 0 12 12">
                    <path d="M6 1v10M1 6h10" />
                  </svg>
                </span>
              </summary>
              <p>{a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}

function FinalCta() {
  return (
    <section className="wrap" id="download">
      <div className="final rv">
        <div className="aur" aria-hidden />
        <div className="caps press" aria-hidden>
          <kbd className="kc">⌃</kbd>
          <kbd className="kc">⌘</kbd>
        </div>
        <h2>Your new Mac starts here.</h2>
        <p>Download once. The hotkeys work the moment it launches.</p>
        <div className="ctas">
          <a className="pill lg" href={DOWNLOAD_URL}>
            <DownloadIcon />
            Download v{VERSION}
          </a>
          <a className="pill lg ghost" href={REPO_URL} target="_blank" rel="noreferrer">
            View on GitHub
          </a>
        </div>
        <div className="sub">
          <div>
            <b>Follow along</b>
            <span>Every release is listed in the changelog and on GitHub.</span>
          </div>
          <a href={RELEASES_URL} target="_blank" rel="noreferrer">
            Latest release →
          </a>
        </div>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Bits
// ---------------------------------------------------------------------------

function Dots() {
  return (
    <span className="dots">
      <i />
      <i />
      <i />
    </span>
  );
}

function Line({ w }: { w: string }) {
  return <span className="ln" style={{ width: w }} />;
}

function Cursor({ className }: { className: string }) {
  return (
    <svg className={className} viewBox="0 0 18 22" aria-hidden>
      <path
        d="M1.5 1.5v16.2l4.2-4 2.9 6.6 2.7-1.2-2.9-6.4h5.9z"
        fill="#1A1A1A"
        stroke="#fff"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function MacIcon() {
  return (
    <svg viewBox="0 0 20 20" aria-hidden>
      <rect x="2.5" y="4" width="15" height="10" rx="1.5" />
      <path d="M1 16.5h18" />
    </svg>
  );
}
