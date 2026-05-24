.PHONY: build open-app run appcast generate-keys fetch-ffmpeg render-icon render-menubar-icon

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

generate-keys:
	@$(eval ARGS := $(filter-out $@,$(MAKECMDGOALS)))
	./scripts/generate-keys.sh $(ARGS)

%:
	@:

