#!/bin/zsh

export_folder=$1
# remove trailing slash
export_folder=${export_folder%/}
app_name="Macaveli"
app_name_no_space="Macaveli"

if [[ -z "$export_folder" ]]; then
    echo "Usage: $0 <folder containing '$app_name.app'>"
    exit 1
fi

if [[ ! -d "$export_folder/$app_name.app" ]]; then
    echo "Usage: $0 <folder containing '$app_name.app'>"
    echo
    echo "Error: $export_folder/$app_name.app does not exist"
    exit 1
fi

# Resolve the public CDN base. The appcast + zip are served from the CDN (not
# GitHub releases) so updates keep working even if the repo goes private.
# Prefer ../.env (single source of truth, shared with upload-dmg.sh); fall back
# to the known DO Spaces URL so `make appcast` still works standalone.
if [[ -f ../.env ]]; then
    set -a; source ../.env; set +a
fi
CDN_BASE="${S3_CDN_URL:-https://macaveli.sfo3.cdn.digitaloceanspaces.com}"

# move current appcast.xml to export folder (canonical copy lives at repo root,
# one level up from macos/, because Sparkle's SUFeedURL points there)
cp ../appcast.xml $export_folder

# zip app
echo "Generating zip file..."
pushd "$export_folder"
zip -9 -y -r -q "${app_name_no_space}.zip" "$app_name.app"
popd

# find Sparkle's bin folder — multiple DerivedData dirs can each carry a copy
# of generate_appcast, so pick the single most recently built one.
generate_appcast=$(find ~/Library/Developer/Xcode/DerivedData/Macaveli* -type f -name "generate_appcast" -exec stat -f '%m %N' {} + 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
if [[ -z "$generate_appcast" ]]; then
    echo "Error: could not find Sparkle's generate_appcast under DerivedData. Build the app first."
    exit 1
fi
bin_folder=$(dirname "$generate_appcast")

# generate appcast
echo "Generating appcast.xml..."
"$generate_appcast" "$export_folder"

# sign update
echo "Signing update..."
"$bin_folder/sign_update" "$export_folder/$app_name_no_space.zip"

# modify appcast.xml so every enclosure points at the CDN-hosted zip
sed -i '' "s|https://[^\"<]*Macaveli\.zip|${CDN_BASE}/Macaveli.zip|g" "$export_folder/appcast.xml"

# copy appcast.xml back to repo root (one level up from macos/)
cp "$export_folder/appcast.xml" ..

