#!/bin/zsh
# Compile the SleepGuard root daemon, embed it in a Macaveli.app bundle, sign
# it, and re-seal the app shell so the bundle's signature stays valid.
#
# SleepGuard is a tiny root LaunchDaemon (see Helper/SleepGuard/main.swift) that
# clears `pmset disablesleep` if the Mac is unplugged while "Never Sleep → even
# when lid is closed" is on — so that dangerous setting can't strand on battery.
#
# It must live at TWO bundle paths for SMAppService.daemon(...) to work:
#   Contents/MacOS/MacaveliSleepGuard                       (the executable)
#   Contents/Library/LaunchDaemons/<label>.plist           (the launchd job)
# Both are inside the signed, notarized bundle on a root-owned, Gatekeeper-
# validated path — no user-writable launch target.
#
# Usage:
#   embed-sleepguard.sh <app-path> [sign-identity] [hardened]
#     <app-path>      path to the .app to embed into (required)
#     [sign-identity] codesign identity substring (default: "Apple Development")
#     [hardened]      "1" to sign with hardened runtime + secure timestamp
#                     (Release/notarized builds); omit for Debug.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"

APP_PATH="${1:?usage: embed-sleepguard.sh <app-path> [sign-identity] [hardened]}"
SIGN_IDENTITY="${2:-Apple Development}"
HARDENED="${3:-0}"

# The app is already signed (by Xcode for Debug, by xcodebuild -exportArchive
# for Release) when we get here. If the caller passed a generic/ambiguous
# identity like "Apple Development" — which can match multiple certs in the
# keychain — derive the EXACT authority from the app's own signature so the
# helper and the re-seal use the same cert. The authority string includes the
# parenthesized team-member id, so it is unambiguous.
if [[ "$SIGN_IDENTITY" != *"("* ]]; then
    DERIVED="$(codesign -dvv "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -1 || true)"
    if [[ -n "$DERIVED" ]]; then
        echo "→ Derived signing identity from app: $DERIVED"
        SIGN_IDENTITY="$DERIVED"
    fi
fi

HELPER_SRC="${REPO_ROOT}/Helper/SleepGuard/main.swift"
HELPER_PLIST="${REPO_ROOT}/Helper/com.jaequery.Macaveli.SleepGuard.plist"
HELPER_NAME="MacaveliSleepGuard"

MACOS_DIR="${APP_PATH}/Contents/MacOS"
DAEMONS_DIR="${APP_PATH}/Contents/Library/LaunchDaemons"
HELPER_BIN="${MACOS_DIR}/${HELPER_NAME}"

[[ -f "$HELPER_SRC" ]]   || { echo "✗ missing $HELPER_SRC" >&2; exit 1; }
[[ -f "$HELPER_PLIST" ]] || { echo "✗ missing $HELPER_PLIST" >&2; exit 1; }
[[ -d "$APP_PATH" ]]     || { echo "✗ no app at $APP_PATH" >&2; exit 1; }

echo "→ Compiling SleepGuard daemon…"
mkdir -p "$MACOS_DIR" "$DAEMONS_DIR"
# Build a universal (arm64 + x86_64) binary so it matches the Release app and
# notarizes cleanly. Min OS 13.0 so SMAppService is available. Each slice is
# compiled separately, then lipo'd together.
TMP_BIN_ARM="$(mktemp -t sleepguard-arm)"
TMP_BIN_X86="$(mktemp -t sleepguard-x86)"
trap 'rm -f "$TMP_BIN_ARM" "$TMP_BIN_X86"' EXIT
swiftc -O -target arm64-apple-macos13.0  -o "$TMP_BIN_ARM" "$HELPER_SRC"
swiftc -O -target x86_64-apple-macos13.0 -o "$TMP_BIN_X86" "$HELPER_SRC"
lipo -create "$TMP_BIN_ARM" "$TMP_BIN_X86" -output "$HELPER_BIN"

echo "→ Embedding LaunchDaemon plist…"
cp "$HELPER_PLIST" "${DAEMONS_DIR}/com.jaequery.Macaveli.SleepGuard.plist"

echo "→ Signing SleepGuard…"
if [[ "$HARDENED" == "1" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$HELPER_BIN"
else
    codesign --force --sign "$SIGN_IDENTITY" "$HELPER_BIN"
fi

echo "→ Re-sealing app shell (SleepGuard changed bundle contents)…"
if [[ "$HARDENED" == "1" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_PATH"
else
    codesign --force --sign "$SIGN_IDENTITY" "$APP_PATH"
fi

echo "✓ SleepGuard embedded at ${HELPER_BIN}"
