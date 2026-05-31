.PHONY: build open-app run appcast generate-keys fetch-ffmpeg render-icon render-menubar-icon dmg upload publish-web appcast-release upload-appcast commit-release release bump-version

fetch-ffmpeg:
	@bash scripts/fetch-ffmpeg.sh

# Render the app icon PNGs + build a proper AppIcon.icns into Macaveli/AppIcon.icns.
# Xcode's asset catalog drops half the size slots on its own; we overwrite the
# bundle's .icns post-build with the full-fidelity one this script produces.
render-icon:
	@swift scripts/render-icon.swift

# Regenerate the menubar icon PNGs (16/32/48 px) into the asset catalog.
# Not chained into `build:` because it's a manual design step — edit the
# renderer, run this, then `make build`.
render-menubar-icon:
	@swift scripts/render-menubar-icon.swift

build: fetch-ffmpeg render-icon
	@# Strip any previously-embedded SleepGuard before xcodebuild re-signs, so the
	@# incremental code-sign step never trips over the helper we add post-build.
	@rm -f "build/Debug/Macaveli.app/Contents/MacOS/MacaveliSleepGuard" \
		"build/Debug/Macaveli.app/Contents/Library/LaunchDaemons/com.jaequery.Macaveli.SleepGuard.plist" 2>/dev/null || true
	xcodebuild -scheme Macaveli build SYMROOT=$(PWD)/build
	@if [ -f Macaveli/AppIcon.icns ]; then \
		cp Macaveli/AppIcon.icns "build/Debug/Macaveli.app/Contents/Resources/AppIcon.icns"; \
		echo "Overwrote bundle .icns with full-fidelity version"; \
	fi
	@./scripts/embed-sleepguard.sh "build/Debug/Macaveli.app" "Apple Development"
	@touch "build/Debug/Macaveli.app"

run-app:
	open "./build/Debug/Macaveli.app"

run: build run-app

appcast:
	@$(eval ARGS := $(filter-out $@,$(MAKECMDGOALS)))
	./scripts/generate-appcast.sh $(ARGS)

# Build a signed + notarized + stapled DMG for distribution.
# See scripts/build-dmg.sh for the one-time signing / notarytool setup.
dmg:
	./scripts/build-dmg.sh

# Upload the versioned DMG to the S3-compatible bucket configured in ../.env
# (DigitalOcean Spaces). Writes the resulting public URL to build/dmg-url.txt.
upload: build/Macaveli.dmg
	./scripts/upload-dmg.sh

# Write web/version.json with the just-uploaded CDN URL, so the landing page
# links to the right versioned DMG. No DMG is copied into web/public/ — the
# bucket hosts it. `make release` commits + pushes this for you via
# commit-release; after a standalone publish-web run `make commit-release`.
publish-web: upload
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/export/Macaveli.app/Contents/Info.plist); \
	URL=$$(cat build/dmg-url.txt); \
	printf '{"version":"%s","downloadUrl":"%s"}\n' "$$VERSION" "$$URL" > ../web/version.json; \
	echo "✓ web/version.json → $$URL"

# Bump MARKETING_VERSION + CURRENT_PROJECT_VERSION in pbxproj.
# Defaults to a patch bump; override with `make bump-version BUMP=minor` or
# `make bump-version VERSION=1.0.0`. `BUMP=none` is a no-op.
bump-version:
	@new=$$(./scripts/bump-version.sh); \
	echo "✓ Version → $$new"

# Commit the version bump + new download URL and push, so the live landing
# page (Vercel, auto-deploys on push) redeploys with the new release. Run from
# `main` — `git push` goes to the current branch's upstream.
commit-release: publish-web
	@VERSION=$$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/export/Macaveli.app/Contents/Info.plist); \
	git add Macaveli.xcodeproj/project.pbxproj ../web/version.json ../appcast.xml; \
	if git diff --cached --quiet; then \
		echo "  Nothing new to commit (same version re-released)"; \
	else \
		git commit -m "release v$$VERSION"; \
	fi; \
	git push; \
	echo "✓ Pushed v$$VERSION — Vercel will redeploy the landing page"

# Regenerate + sign appcast.xml from the exported app (build/export) so Sparkle
# offers the update to existing users. The feed points at the GitHub 'latest'
# release asset (Macaveli.zip) — publishing the GitHub release uploads that zip.
appcast-release:
	./scripts/generate-appcast.sh build/export

# Push the regenerated appcast.xml + signed Macaveli.zip to the CDN bucket so
# Sparkle (whose SUFeedURL points at the CDN, not GitHub) can serve them — works
# whether the repo is public or private. Run after appcast-release.
upload-appcast:
	./scripts/upload-appcast.sh

# Full release in ONE command: bump version → build + notarize DMG → upload DMG
# to the CDN → update web/version.json → regenerate Sparkle appcast → upload the
# appcast + signed zip to the CDN → commit + push. Vercel auto-deploys the site;
# Sparkle's feed is served from the CDN (works even if the repo goes private), and
# the committed appcast.xml is the source of truth. Re-release same version
# without bumping: `BUMP=none make release`.
release: bump-version dmg upload publish-web appcast-release upload-appcast commit-release

generate-keys:
	@$(eval ARGS := $(filter-out $@,$(MAKECMDGOALS)))
	./scripts/generate-keys.sh $(ARGS)

%:
	@:

