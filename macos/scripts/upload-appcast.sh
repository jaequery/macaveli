#!/bin/zsh
# Uploads the Sparkle appcast + signed update zip to the S3-compatible bucket
# configured in ../.env (DigitalOcean Spaces by default), so auto-updates work
# regardless of whether the GitHub repo is public or private.
#
# Run after `make appcast-release` (which regenerates ../appcast.xml and the
# signed build/export/Macaveli.zip). The Makefile wires this in as
# `make upload-appcast`, between appcast-release and commit-release.
#
# Both objects use stable keys (appcast.xml, Macaveli.zip) and are OVERWRITTEN
# every release, so they are uploaded with `no-cache` — marking them immutable
# would make the CDN serve a stale appcast/zip after the next release and
# silently break updates.

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

APPCAST="${REPO_ROOT}/appcast.xml"
ZIP="build/export/Macaveli.zip"

if [[ ! -f "$APPCAST" ]]; then
    echo "✗ $APPCAST missing — run 'make appcast-release' first." >&2
    exit 1
fi
if [[ ! -f "$ZIP" ]]; then
    echo "✗ $ZIP missing — run 'make appcast-release' first." >&2
    exit 1
fi

# Upload the zip FIRST, then the appcast — so the appcast never references a zip
# that isn't on the CDN yet.
echo "→ Uploading $ZIP"
echo "    → s3://${S3_BUCKET}/Macaveli.zip"
aws s3 cp "$ZIP" "s3://${S3_BUCKET}/Macaveli.zip" \
    --endpoint-url "$S3_UPLOAD_ENDPOINT" \
    --region "$AWS_REGION" \
    --acl public-read \
    --content-type application/zip \
    --cache-control "no-cache"

echo "→ Uploading appcast.xml"
echo "    → s3://${S3_BUCKET}/appcast.xml"
aws s3 cp "$APPCAST" "s3://${S3_BUCKET}/appcast.xml" \
    --endpoint-url "$S3_UPLOAD_ENDPOINT" \
    --region "$AWS_REGION" \
    --acl public-read \
    --content-type application/xml \
    --cache-control "no-cache"

echo
echo "✓ Uploaded"
echo "    ${S3_CDN_URL}/Macaveli.zip"
echo "    ${S3_CDN_URL}/appcast.xml"
