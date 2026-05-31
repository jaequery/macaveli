#!/bin/zsh
# Builds a signed + notarized + stapled .dmg for distribution.
#
# Output:
#   macos/build/Macaveli-<version>.dmg   (versioned, kept for archival)
#   macos/build/Macaveli.dmg             (stable filename, what the web links to)
#
# One-time setup:
#   1. Install a "Developer ID Application" cert from your Apple Developer
#      account into the login keychain.
#   2. Create a notarytool keychain profile (one-time):
#        xcrun notarytool store-credentials macaveli-notary \
#            --apple-id  <your apple id email> \
#            --team-id   7BWUZV469T \
#            --password  <app-specific password from appleid.apple.com>
#
# Env overrides:
#   SKIP_NOTARIZE=1   skip the notarytool submit/staple step (faster, but
#                     Gatekeeper will warn users — only for local testing)
#   NOTARY_PROFILE    keychain profile name (default: macaveli-notary)
#   SIGN_IDENTITY     codesign identity substring (default: "Developer ID Application")

set -euo pipefail

APP_NAME="Macaveli"
TEAM_ID="${TEAM_ID:-7BWUZV469T}"
NOTARY_PROFILE="${NOTARY_PROFILE:-macaveli-notary}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
BUILD_DIR="${REPO_ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
EXPORT_PLIST="${BUILD_DIR}/ExportOptions.plist"

# ---- Pre-flight ----------------------------------------------------------

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    cat >&2 <<EOF
✗ No "Developer ID Application" certificate found in your keychain.

  This cert is required to ship a notarized DMG. Get one at:
    https://developer.apple.com/account/resources/certificates/list

  Pick "Developer ID Application", download the .cer, double-click to install.
  Then re-run this script.
EOF
    exit 1
fi

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
    if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        cat >&2 <<EOF
✗ notarytool keychain profile "$NOTARY_PROFILE" not found.

  Create it once with:
    xcrun notarytool store-credentials $NOTARY_PROFILE \\
        --apple-id you@example.com \\
        --team-id  $TEAM_ID \\
        --password <app-specific password from appleid.apple.com>

  Or skip notarization for local testing:
    SKIP_NOTARIZE=1 make dmg
EOF
        exit 1
    fi
fi

# ---- 1. Make sure ffmpeg + icon are present (same as `make build`) -------

bash scripts/fetch-ffmpeg.sh
swift scripts/render-icon.swift

# ---- 2. Archive in Release ----------------------------------------------

rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

echo "→ Archiving (Release)…"
xcodebuild -scheme "$APP_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    archive

# ---- 3. Export Developer ID-signed .app ---------------------------------

cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

echo "→ Exporting Developer ID build…"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST"

# Overwrite the asset-catalog .icns with our full-fidelity one (same as the
# Debug build path in the Makefile).
if [[ -f "Macaveli/AppIcon.icns" ]]; then
    cp "Macaveli/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
fi

# ---- 4. Re-sign bundled binaries Xcode might miss -----------------------
#
# ffmpeg is copied as a Resource (not as a build-phase "Embed & Sign"),
# so the export step won't re-sign it with our Developer ID. Notarization
# requires every Mach-O inside the bundle to be signed with hardened runtime
# + secure timestamp, so we sign it explicitly here, then re-sign the outer
# .app shell so its seal stays valid.

FFMPEG_BIN="$APP_PATH/Contents/Resources/ffmpeg"
if [[ -f "$FFMPEG_BIN" ]]; then
    echo "→ Re-signing bundled ffmpeg…"
    codesign --force \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        "$FFMPEG_BIN"
fi

# Compile + embed + sign the SleepGuard root daemon (hardened runtime), then
# re-seal the app shell. This script re-signs the outer .app itself, so it
# replaces the standalone shell re-sign that used to live here. See
# scripts/embed-sleepguard.sh and Helper/SleepGuard/main.swift.
echo "→ Embedding SleepGuard daemon…"
bash scripts/embed-sleepguard.sh "$APP_PATH" "$SIGN_IDENTITY" 1

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# ---- 5. Build the DMG ---------------------------------------------------
#
# Two-step build: create a writable DMG, mount it and style the Finder
# window via AppleScript (icon size, positions, no toolbar/sidebar), then
# convert to a compressed read-only DMG. This is what produces the big
# "drag-the-app-into-Applications" installer window users expect.

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"
VOLUME_NAME="${APP_NAME} ${VERSION}"
RW_DMG="${BUILD_DIR}/${APP_NAME}-rw.dmg"
MOUNT_DIR="/Volumes/${VOLUME_NAME}"

rm -rf "$STAGING" "$DMG_PATH" "$RW_DMG"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "→ Building writable DMG…"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$RW_DMG"

# Detach any leftover mount from a previous failed run, then attach fresh.
hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
echo "→ Mounting writable DMG for styling…"
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen >/dev/null

echo "→ Styling Finder window…"
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- {left, top, right, bottom} → 660 × 420 window
        set the bounds of container window to {240, 140, 900, 560}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set label position of viewOptions to bottom
        set shows item info of viewOptions to false
        set shows icon preview of viewOptions to true
        set position of item "${APP_NAME}.app" of container window to {180, 200}
        set position of item "Applications" of container window to {480, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync

echo "→ Detaching writable DMG…"
hdiutil detach "$MOUNT_DIR" -force

echo "→ Compressing to read-only DMG…"
hdiutil convert "$RW_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

rm -f "$RW_DMG"

echo "→ Signing DMG…"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

# ---- 6. Notarize + staple ----------------------------------------------

if [[ "$SKIP_NOTARIZE" != "1" ]]; then
    echo "→ Notarizing (waits for Apple — can take a few minutes)…"
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "→ Stapling notarization ticket…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
else
    echo "⚠ SKIP_NOTARIZE=1 — DMG is signed but not notarized."
fi

# ---- 7. Stable-name copy for the website -------------------------------

cp "$DMG_PATH" "${BUILD_DIR}/${APP_NAME}.dmg"

echo
echo "✓ DMG ready"
echo "    $DMG_PATH"
echo "    ${BUILD_DIR}/${APP_NAME}.dmg   (stable name)"
echo
echo "  Next: 'make publish-web' to copy it into web/public/."
