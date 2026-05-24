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

echo "→ Re-signing app shell…"
codesign --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --timestamp \
    "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

# ---- 5. Build the DMG ---------------------------------------------------

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
STAGING="${BUILD_DIR}/dmg-staging"

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "→ Building DMG…"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

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
