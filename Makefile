APP_NAME      := AIUsages
BUNDLE_NAME   := AI Usages
BUNDLE_ID     := com.melissasoft.aiusages
CONFIGURATION ?= release
DIST          := dist
BUILD_DIR     := build
APP           := $(DIST)/$(BUNDLE_NAME).app
INSTALL_DIR   ?= /Applications
SWIFT         := swift
VERSION       := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

.PHONY: all build bundle zip run install uninstall clean test

all: bundle

## Compile the Swift package (release by default).
build:
	@if [ "$$(uname -m)" != "arm64" ]; then \
		echo "$(BUNDLE_NAME) requires Apple Silicon (arm64)."; \
		exit 1; \
	fi
	$(SWIFT) build -c $(CONFIGURATION)

## Run the correctness tests. CommandLineTools-only installs need an explicit
## plugin path for Swift Testing; Xcode installs work without it.
test:
	@PLUGIN_DIR="$$(find /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing /Applications/Xcode.app -name 'libTestingMacros.dylib' -maxdepth 12 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null)"; \
	if [ -n "$$PLUGIN_DIR" ]; then \
		$(SWIFT) test -Xswiftc -plugin-path -Xswiftc "$$PLUGIN_DIR"; \
	else \
		$(SWIFT) test; \
	fi

## Assemble dist/AI Usages.app.
bundle: build
	@./Scripts/build_app.sh

## Package dist/AIUsages-<version>.zip for GitHub release / Homebrew cask.
zip:
	@./Scripts/package_release.sh

## Build and launch the bundle from build/.
run: bundle
	@./Scripts/run.sh

## Install into /Applications.
install: bundle
	@./Scripts/install.sh

uninstall:
	@pkill -f "AIUsages" 2>/dev/null || true
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE_NAME).app"
	@echo "==> Removed $(INSTALL_DIR)/$(BUNDLE_NAME).app"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST)" .build
	$(SWIFT) package clean
