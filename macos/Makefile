.PHONY: build open-app run appcast generate-keys fetch-ffmpeg render-icon render-menubar-icon dmg publish-web release

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
	xcodebuild -scheme Macaveli build SYMROOT=$(PWD)/build
	@if [ -f Macaveli/AppIcon.icns ]; then \
		cp Macaveli/AppIcon.icns "build/Debug/Macaveli.app/Contents/Resources/AppIcon.icns"; \
		echo "Overwrote bundle .icns with full-fidelity version"; \
	fi
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

# Copy the latest DMG into web/public/ so the marketing site serves it
# at /Macaveli.dmg. Run after `make dmg`.
publish-web: build/Macaveli.dmg
	@mkdir -p ../web/public
	cp build/Macaveli.dmg ../web/public/Macaveli.dmg
	@echo "✓ Copied to web/public/Macaveli.dmg"
	@echo "  Commit it (or deploy it) for the website Download button to work."

# Full release: build the DMG and drop it into the web app.
release: dmg publish-web

generate-keys:
	@$(eval ARGS := $(filter-out $@,$(MAKECMDGOALS)))
	./scripts/generate-keys.sh $(ARGS)

%:
	@:

