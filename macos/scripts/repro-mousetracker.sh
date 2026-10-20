#!/usr/bin/env bash
# Compiles the real MouseTracker.swift against headless stubs and runs the
# MACA-59KJM0 repro (leaked NSEvent monitors, 4 s drag cut-off). Exit 0 = fixed.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -module-name Repro -o "$out/repro" \
    "$here/../Macaveli/src/Manager/MouseTracker.swift" \
    "$here/repro-mousetracker/Stubs.swift" \
    "$here/repro-mousetracker/main.swift"
"$out/repro"
