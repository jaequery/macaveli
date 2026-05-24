#!/bin/zsh
# Bumps MARKETING_VERSION and CURRENT_PROJECT_VERSION in the Xcode project
# (both Debug and Release configs).
#
# Env overrides:
#   BUMP=patch|minor|major|none   which part to bump (default: patch)
#   VERSION=X.Y.Z                 set an exact version, skipping BUMP
#
# Prints the new version to stdout. Idempotent when BUMP=none.

set -euo pipefail

cd "$(dirname "$0")/.."             # macos/
PBXPROJ="Macaveli.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    echo "✗ $PBXPROJ not found." >&2
    exit 1
fi

current=$(grep -m1 "MARKETING_VERSION = " "$PBXPROJ" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' \
    | tr -d '[:space:]')

if [[ -z "$current" ]]; then
    echo "✗ Could not read MARKETING_VERSION from $PBXPROJ" >&2
    exit 1
fi

if [[ -n "${VERSION:-}" ]]; then
    new="$VERSION"
else
    bump="${BUMP:-patch}"
    if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "✗ MARKETING_VERSION '$current' is not X.Y.Z — set VERSION=x.y.z explicitly" >&2
        exit 1
    fi
    local major=${match[1]} minor=${match[2]} patch=${match[3]}
    case "$bump" in
        major) new="$((major + 1)).0.0" ;;
        minor) new="${major}.$((minor + 1)).0" ;;
        patch) new="${major}.${minor}.$((patch + 1))" ;;
        none)  new="$current" ;;
        *)
            echo "✗ BUMP must be major|minor|patch|none (got '$bump')" >&2
            exit 1
            ;;
    esac
fi

if [[ "$new" == "$current" ]]; then
    echo "$new"
    exit 0
fi

# Both MARKETING_VERSION and CURRENT_PROJECT_VERSION appear twice in pbxproj
# (Debug + Release). The /g flag updates them all in one pass.
# BSD sed (macOS) requires the empty '' after -i.
sed -i '' -E "s/(MARKETING_VERSION = )${current}( ?;)/\1${new}\2/g" "$PBXPROJ"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )${current}( ?;)/\1${new}\2/g" "$PBXPROJ"

# Verify the bump landed in both configurations.
count=$(grep -c "MARKETING_VERSION = ${new};" "$PBXPROJ" || true)
if [[ "$count" -lt 2 ]]; then
    echo "✗ Bumped only ${count}/2 MARKETING_VERSION entries — pbxproj structure may have changed." >&2
    exit 1
fi

echo "$new"
