# FREDRIN.md

Configuration and working guidelines for this project on **Fredrin** — the
desktop kanban for running many AI-coding tickets in parallel. This file is
committed to the repo, fully customizable, and read by every Worker at the start
of a session. Edit it to fit your team; run **Reset to defaults** from the
Context tab to restore this template.

## What a ticket is

A **ticket** is one unit of work that runs through a single AI agent session (a
**Worker**) in its own branch and **worktree**. Throughput comes from running
many tickets in parallel — one ticket, one Worker. Tickets are GitHub-shaped: a
ticket has a branch, optionally a PR, and CI status flowing back to the board.
Merging the PR auto-completes the ticket.

## Kanban workflow

Tickets move left-to-right across the board, driven by **deterministic signals**
— no model discipline required:

1. **Backlog** — captured, not yet started. Human presses Run → spawns a session.
2. **Running** — a Worker is actively working (session just started).
3. **Blocked** — human-marked; the Worker needs input before continuing.
4. **Review** — the session ended; a human glances at the diff and ships or sends back.
5. **Completed** — the human clicked Complete (or the PR merged).

The board column is driven by Claude Code's lifecycle hooks (SessionStart →
Running, Stop/SessionEnd → Review) plus one explicit human action for Completed.
You do not need to call any CLI to move the ticket — running your work is enough.

## The `./.fredrin/fredrin` CLI

Each session's worktree gets a `./.fredrin/fredrin` wrapper (git-ignored; it carries
a scoped API token). Use it to read or mutate the current ticket:

- `./.fredrin/fredrin get` — fetch the current ticket
- `./.fredrin/fredrin update-plan <<'PLAN'` … `PLAN` — save the implementation plan
  from **stdin** (preferred; no JSON escaping, no temp file). Use markdown with a
  `## Action items` GFM checklist (`- [ ]` / `- [x]`). Do NOT `jq` a temp file or
  hand-build `'{"plan":"..."}'` — a blocked or partial temp-file write makes jq
  slurp stale content and saves the wrong plan.
- `./.fredrin/fredrin check <n>` / `uncheck <n>` — flip ONE action item by its
  1-based position in the plan without re-sending the whole plan. Cheap and atomic,
  so during **Build** flip each item the moment you finish it — progress then
  updates in real time.
- `./.fredrin/fredrin update '{"plan":"..."}'` — same effect as `update-plan` via
  inline JSON (only if you cannot use a heredoc)
- `./.fredrin/fredrin update '{"description":"..."}'` — PATCH ticket fields
- `./.fredrin/fredrin comment '{"body":"..."}'` — post a comment
- `./.fredrin/fredrin choices '{"question":"...","options":[...]}'` — offer the user
  clickable next-step chips (see below)
- `./.fredrin/fredrin screenshot <url>` — capture a screenshot of `url`, upload it, and
  attach it to this ticket as an artifact (no `url` → captures the PR preview). Run this
  the moment the user asks to "take a screenshot of …" or "upload a screenshot" — the
  server does the Playwright capture + S3 upload + attach; you never touch either directly.
- `./.fredrin/fredrin upload <file> [--label text] [--kind before|after] [--pair key]` —
  attach a LOCAL file (screenshot, screen recording, HTML mockup, log) to this ticket as
  an artifact. For before/after evidence, upload the pre-change capture with `--kind
  before` and the post-change capture with `--kind after`, reusing the same `--pair`
  slug per screen so the board shows them side by side.
- `./.fredrin/fredrin finish '{"checks":[...],"summary":"..."}'` — **your final act.** Records your
  acceptance-check results and, only if every check is green, pushes the branch, opens the PR
  (reusing one if it already exists), and moves the ticket to Review — all in one call. On a red
  check it records the failure (needs-work) and opens no PR. It only ever opens a PR — never merges,
  never pushes to the base branch.
- `./.fredrin/fredrin ship '{...}'` — record an already-open PR URL (board moves to Review). Prefer
  `finish`, which calls this for you once the build is green.
- `./.fredrin/fredrin error '{"reason":"...","where":"..."}'` — surface a build failure

Do not echo or log the contents of `./.fredrin/fredrin` — it holds a credential.

## Building a ticket

When you start a Build, treat the plan's **acceptance checks** as the contract —
its definition of done, and a live checklist, not a list flipped (if ever) at the
very end:

- **Review them upfront.** Before writing any code, read every acceptance check
  from the plan (`./.fredrin/fredrin get`) and, for each, restate the concrete
  pass/fail signal you will drive it to — the command to run, the HTTP response,
  the UI state to observe. Build toward verifiable outcomes, not vibes.
- **Validate with evidence, tick as you go.** The moment you finish an item,
  confirm it is actually met by running its command or observing its state — real
  evidence, never self-graded prose — then immediately `./.fredrin/fredrin check <n>`
  it (`<n>` is its 1-based position in plan order). Do this one item at a time as
  you go, never batched at the end, so the board shows real-time progress. Only
  ever check an item you have positively verified.
- **Verify, then finish — in one breath.** Your LAST action is `fredrin finish`
  with your acceptance-check results (real exit codes, never assumed). A finished
  build with **no PR** is the failure to avoid: on a fully green result `finish`
  pushes the branch, opens the PR, and moves the ticket to Review; on any red check
  it records the failure (needs-work) and opens no PR — fix the cause and run it
  again. See **Ending the session** below.

## Offering choices

When you would end a turn by asking the user to pick between options, call
`fredrin choices` instead of only listing them in prose — the panel turns each option
into a clickable chip (`label` is shown, `value` is sent back as the reply).
Provide 1–6 options; keep labels ≤ 80 chars.

## Ending the session

The board column moves to Review automatically when your session ends (the Stop
hook) — but a finished build with **no PR** is the exact failure to avoid, so make
opening a PR part of finishing:

- **Work is done** → run `fredrin finish` with your acceptance-check results. If every
  check is green it pushes the branch, opens the PR, and moves the ticket to Review in
  one call; if any check is red it records the failure (needs-work) and opens no PR.
- **Build failed** → call `fredrin error` to surface the failure.
- Never call `finish`/`ship` and `error` in the same session.

## Shipping (when the work is done)

Prefer the one-call finisher — it makes opening a PR deterministic instead of a
multi-step sequence you might skip:

    ./.fredrin/fredrin finish '{"checks":[{"command":"pnpm typecheck","exitCode":0}],"summary":"..."}'

`finish` records your verification and, **only on a fully green result**, runs the
steps below for you (push → open/reuse PR → record it → Review). Commit everything
first (it refuses on a dirty tree) and run the acceptance checks yourself so you
pass their real exit codes.

If you must do it by hand (e.g. `finish` reports a problem it can't resolve), run
this exact sequence — no improvisation, no skipping steps:

1. **Detect the default branch** into `$BASE`
   (`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, falling
   back to `git symbolic-ref refs/remotes/origin/HEAD` /
   `git remote show origin`). If none resolve, `fredrin error` with
   `where:"detect-base"` and stop.
2. **Commit** all changes with a clear conventional message (subject ≤ 72 chars,
   imperative; body explains *why*). Project Context changes go in their own
   commits prefixed `context:`.
3. **Push** the working branch: `git push -u origin HEAD`. On rejection,
   `fredrin error` with `where:"push"` and stop.
4. **Open the PR** — prefer
   `gh pr create --base "$BASE" --title "..." --body "..."`. End the body with
   `Closes ticket: <the current ticket's identifier>` (see the session preamble
   or `fredrin get`).
5. **Record it**:
   `fredrin ship '{"prUrl":"...","summary":"...","branch":"...","targetBranch":"..."}'`.

Hard rules:

- Never merge the PR yourself; never push to the base branch. `finish` opens a PR
  and nothing more — it never merges or releases.
- Never change the ticket's status with `fredrin update` — `finish` / `ship` /
  `error` are the status-recording calls; the board column moves from hooks, not
  from explicit finish calls.
- Never call `finish`/`ship` and `error` in the same session.
- If the ticket already has a PR for this branch, `finish` reuses it; only branch
  fresh from `$BASE` with a new name when you truly need a separate PR.

## Team guidelines

Customize this section for your project — coding standards, review expectations,
definition of done, branch naming, and anything every Worker should know before
touching code. Durable project knowledge (glossary, decisions, conventions)
belongs in your Project Context files (`CONTEXT.md`, `AGENTS.md`, `docs/adr/`),
not here.
