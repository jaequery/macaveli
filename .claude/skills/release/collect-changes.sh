#!/bin/zsh
# Gather the raw material the /release skill summarizes into changelog notes.
# Read-only. Prints the current version, the commit range since the last
# release, every commit (subject + body) in that range, and a diffstat.
#
# Usage: .claude/skills/release/collect-changes.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PBXPROJ="macos/Macaveli.xcodeproj/project.pbxproj"
CURVER=$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d '[:space:]')
echo "CURRENT_VERSION=$CURVER"

# The release history is recorded as commits subject-lined "release vX.Y.Z".
LAST=$(git log --grep='^release v' -1 --format=%H 2>/dev/null || true)

if [[ -z "$LAST" ]]; then
    echo "LAST_RELEASE_COMMIT=(none found)"
    echo "=== LAST 20 COMMITS (no prior release tag) ==="
    git log -20 --no-merges --format='- %s'
    exit 0
fi

echo "LAST_RELEASE_COMMIT=$LAST"
echo "LAST_RELEASE_SUBJECT=$(git log -1 --format=%s "$LAST")"
echo "RANGE=${LAST:0:9}..HEAD"
echo ""
echo "=== COMMITS SINCE LAST RELEASE (subject + body) ==="
git log "$LAST..HEAD" --no-merges --format='%n- %s%n%w(0,4,4)%b'
echo ""
echo "=== FILES CHANGED SINCE LAST RELEASE ==="
git diff --stat "$LAST..HEAD"
