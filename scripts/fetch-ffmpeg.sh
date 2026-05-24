#!/bin/zsh
# Downloads a static universal (arm64 + x86_64) ffmpeg binary and bundles it
# into Macaveli/ffmpeg so the .app can ship with it. Idempotent: if the file
# already exists and is a valid Mach-O executable, exits early.
#
# Source: osxexperts.net provides static GPL builds for both architectures.
# These include libx264 (H.264 encoder) and the palettegen/paletteuse filters
# we need for high-quality GIF encoding.

set -euo pipefail

cd "$(dirname "$0")/.."
DEST="Macaveli/ffmpeg"

if [[ -f "$DEST" ]] && file "$DEST" | grep -q "Mach-O"; then
    echo "ffmpeg already bundled at $DEST ($(du -h "$DEST" | cut -f1))"
    exit 0
fi

ARM_URL="https://www.osxexperts.net/ffmpeg7arm.zip"
INTEL_URL="https://www.osxexperts.net/ffmpeg7intel.zip"

TMP="$(mktemp -d)"
trap "rm -rf $TMP" EXIT

echo "Downloading ffmpeg arm64..."
curl --fail --location --silent --show-error \
    -o "$TMP/arm.zip" "$ARM_URL"
unzip -q "$TMP/arm.zip" -d "$TMP/arm"

echo "Downloading ffmpeg x86_64..."
curl --fail --location --silent --show-error \
    -o "$TMP/intel.zip" "$INTEL_URL"
unzip -q "$TMP/intel.zip" -d "$TMP/intel"

ARM_BIN="$(find "$TMP/arm" -type f -name 'ffmpeg' | head -1)"
INTEL_BIN="$(find "$TMP/intel" -type f -name 'ffmpeg' | head -1)"

if [[ -z "$ARM_BIN" || -z "$INTEL_BIN" ]]; then
    echo "Error: could not locate extracted ffmpeg binaries" >&2
    echo "Looked in $TMP/arm and $TMP/intel" >&2
    exit 1
fi

echo "Creating universal binary..."
lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$DEST"
chmod +x "$DEST"

echo "Codesigning (ad-hoc; Xcode re-signs on build with the app's identity)..."
codesign --force --sign - "$DEST"

SIZE="$(du -h "$DEST" | cut -f1)"
ARCHS="$(lipo -archs "$DEST")"
VERSION="$("$DEST" -version 2>/dev/null | head -1 || echo 'unknown')"
echo "Done."
echo "  path:    $DEST"
echo "  size:    $SIZE"
echo "  archs:   $ARCHS"
echo "  version: $VERSION"
