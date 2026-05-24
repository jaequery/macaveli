#!/bin/zsh
# Uploads build/Macaveli-<VERSION>.dmg to the S3-compatible bucket configured
# in ../.env (DigitalOcean Spaces by default) with public-read ACL, and writes
# the resulting CDN URL to build/dmg-url.txt for downstream steps.
#
# Run after `make dmg`. The Makefile wires this in as `make upload`.

set -euo pipefail

cd "$(dirname "$0")/.."             # macos/
REPO_ROOT="$(cd .. && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    cat >&2 <<EOF
✗ ${ENV_FILE} not found.

  Copy .env.example → .env at the repo root and fill in your S3/Spaces
  credentials. The file is gitignored — never commit it.
EOF
    exit 1
fi

# Load credentials (set -a exports every var defined while it's on).
set -a
source "$ENV_FILE"
set +a

: "${S3_BUCKET:?S3_BUCKET missing in .env}"
: "${S3_CDN_URL:?S3_CDN_URL missing in .env}"
: "${S3_UPLOAD_ENDPOINT:?S3_UPLOAD_ENDPOINT missing in .env}"
: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID missing in .env}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY missing in .env}"
: "${AWS_REGION:=us-east-1}"

if ! command -v aws >/dev/null 2>&1; then
    cat >&2 <<EOF
✗ aws CLI not found.

  Install once with:  brew install awscli
  (DigitalOcean Spaces is S3-compatible, so the AWS CLI works against it.)
EOF
    exit 1
fi

APP_PLIST="build/export/Macaveli.app/Contents/Info.plist"
if [[ ! -f "$APP_PLIST" ]]; then
    echo "✗ $APP_PLIST missing — run 'make dmg' first." >&2
    exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PLIST")

DMG="build/Macaveli-${VERSION}.dmg"
if [[ ! -f "$DMG" ]]; then
    echo "✗ $DMG missing — run 'make dmg' first." >&2
    exit 1
fi

KEY="Macaveli-${VERSION}.dmg"
URL="${S3_CDN_URL}/${KEY}"

echo "→ Uploading $DMG"
echo "    → s3://${S3_BUCKET}/${KEY}"
aws s3 cp "$DMG" "s3://${S3_BUCKET}/${KEY}" \
    --endpoint-url "$S3_UPLOAD_ENDPOINT" \
    --region "$AWS_REGION" \
    --acl public-read \
    --content-type application/x-apple-diskimage \
    --cache-control "public, max-age=31536000, immutable"

echo "$URL" > build/dmg-url.txt
echo
echo "✓ Uploaded"
echo "    $URL"
