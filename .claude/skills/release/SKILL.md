---
name: release
description: >
  Full Macaveli release flow, start to finish, no hiccups. Bumps the version,
  AI-summarizes the commits since the last release into a user-facing changelog
  entry, builds + notarizes + uploads the DMG, publishes the website version +
  Sparkle appcast, then commits and pushes. Use when the user says "/release",
  "cut a release", "ship a release", "release Macaveli", "do a full release",
  "publish a new version", or "release it".
---

# Release Macaveli (full flow)

One command takes the repo from "feature is done on `main`" to "published to
users." This skill exists because the raw `make release` has two sharp edges that
silently produce a broken release if you forget them — this flow handles both:

1. **`make release` does NOT write the changelog.** Its `commit-release` step
   only stages `project.pbxproj`, `web/version.json`, and `appcast.xml`. The
   user-facing changelog (`web/app/changelog/data.ts`) and any uncommitted
   **source files** are never committed by it. So they must be committed *before*
   `make release` runs, or `main` ends up with a version bump whose source/notes
   aren't in git.
2. **The changelog is AI-authored here.** You read the commits since the last
   release and write benefit-oriented notes — not raw commit subjects.

## Hard rules (these are the hiccups — do not skip)

- **`make` runs from `macos/`. `git` and the changelog edit run from the repo
  root.** Never run `make` from the root.
- **Author the changelog BEFORE running `make release`,** and commit it together
  with any uncommitted source changes in one commit. `make release` only commits
  the version-bump artifacts after.
- **Pass `VERSION=<next>` to `make release`** so the number you wrote in the
  changelog and the number the build stamps are guaranteed identical. Don't let
  `bump-version` pick a different number than the changelog says.
- **Run `make release` in the background and wait on it** — it notarizes (Apple
  round-trip, minutes). Foreground `sleep`-polling is blocked by the harness.
  Use `run_in_background: true` writing to a log file, then wait with `Monitor`
  on `grep -q RELEASE_EXIT <log>`.
- **The release is public + irreversible** (notarized DMG + CDN upload + git
  push that triggers a Vercel redeploy). Confirm version + changelog with the
  user before firing it, unless they passed `--yes`.
- **Verify at the end** against git + `version.json` + `appcast.xml`. A green
  `make` is not proof; check the artifacts.

## Arguments

`$ARGUMENTS` may contain:
- a bump level: `patch` (default), `minor`, or `major`;
- or an exact version: `1.2.3`;
- `--yes` / `-y` to skip the confirmation gate (use only if the user clearly
  asked to ship without review).

Feature work since the last release leans `minor`; pure fixes lean `patch`. When
unsure, propose one and let the user confirm at the gate.

## Procedure

### 0. Preflight
- `cd` to repo root. Confirm branch is `main` (`git branch --show-current`). If
  not, stop and ask — releases cut from `main`.
- `git status --porcelain` — note uncommitted work; it will be folded into the
  pre-release commit in step 4. (Don't discard anything.)
- Confirm there ARE changes to release: if there are no commits since the last
  release AND no uncommitted work, stop — nothing to ship.

### 1. Collect the changes
Run the helper and read its output:
```
.claude/skills/release/collect-changes.sh
```
It prints `CURRENT_VERSION`, the commit range, each commit (subject + body), and
the changed-files diffstat — the raw material to summarize.

### 2. Decide the next version + draft the changelog (the AI step)
- Compute `NEXT` from `CURRENT_VERSION` and the bump level (default `patch`;
  `minor`/`major`/explicit per `$ARGUMENTS`). Patch = bump the last number.
- Read the commits + diffstat and **synthesize user-facing release notes**:
  - Group into `Change` items, each `{ type: "feature" | "fix" | "improvement", text }`.
  - Write benefits, not commit messages. "Set your key-repeat speed past the
    macOS slider floor," not "feat: add KeyRepeatManager."
  - Optional one-line `summary` if there's a headline theme.
  - Be honest about caveats the user cares about (e.g. "takes effect after
    logout") rather than overselling.
- Insert a new `Release` object at the **top** of the `releases` array (newest
  first) in `web/app/changelog/data.ts`. Use today's date (`date +%F`). Shape:
  ```ts
  {
    version: "<NEXT>",
    date: "YYYY-MM-DD",
    summary: "<optional one-liner>",
    changes: [
      { type: "feature", text: "…" },
      { type: "fix", text: "…" },
    ],
  },
  ```

### 3. Confirmation gate (unless `--yes`)
Show the user: the chosen `NEXT` version and the drafted changelog entry. Ask to
proceed / edit / change the version. Apply edits, then continue.

### 4. Commit source + changelog (pre-release commit)
From repo root, stage everything that is NOT a release artifact and commit:
```
git add -A
git commit -m "<concise feat/fix summary of this release's work>

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
(If the working tree was already clean and the changelog is the only change, this
commit is just the changelog — that's fine.)

### 5. Run the release (background + wait)
From `macos/`, in the background, logging to a file:
```
cd macos && VERSION=<NEXT> make release > /tmp/macaveli-release.log 2>&1; echo "RELEASE_EXIT=$?" >> /tmp/macaveli-release.log
```
Launch it with `run_in_background: true`. Then wait with `Monitor`:
```
until grep -q "RELEASE_EXIT" /tmp/macaveli-release.log; do sleep 3; done; \
  echo "DONE $(grep -o 'RELEASE_EXIT=[0-9]*' /tmp/macaveli-release.log)"; \
  grep -E "Pushed|✗|error:|fatal|invalid" /tmp/macaveli-release.log | tail -10
```
Give Monitor a generous `timeout_ms` (e.g. 900000). `make release` runs:
`bump-version → dmg (build+notarize+staple) → upload → publish-web →
appcast-release → upload-appcast → commit-release (commit + push)`.

### 6. Verify the artifacts
```
grep -o 'RELEASE_EXIT=[0-9]*' /tmp/macaveli-release.log     # want =0
git log --oneline -2                                         # want "release v<NEXT>" on top
cat web/version.json                                         # version == <NEXT>, dmg URL == <NEXT>
git status -sb | head -1                                     # want in sync with origin/main (not "ahead")
grep -c "<NEXT>" appcast.xml                                 # appcast mentions new version
grep -E "staple and validate|✓ DMG ready" /tmp/macaveli-release.log   # notarized + stapled
```
If `RELEASE_EXIT` is not `0`, or the release commit didn't push, **stop and
report exactly which stage failed** (read the log tail) — do not pretend success.
Common stalls: notarization rejection, missing CDN creds in repo-root `.env`,
missing Developer ID cert / notary profile (see `macos/CLAUDE.md` one-time setup).

### 7. Report
Summarize: version shipped, the changelog entry, that the DMG is notarized + on
the CDN, that `main` is pushed (Vercel redeploys the site), and that existing
users get it via Sparkle auto-update.

## Notes
- Versioning convention in this repo: releases are recorded as `release vX.Y.Z`
  commits (no git tags). `collect-changes.sh` finds the last one via
  `git log --grep='^release v'`.
- Re-release the same version without bumping (rare): `cd macos && BUMP=none make release`.
- The website download link updates automatically when the pushed
  `web/version.json` triggers the Vercel redeploy.
