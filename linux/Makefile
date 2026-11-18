SHELL := /bin/sh

UUID := aiusages@melissasoft
EXT_DIR := extension/$(UUID)
DIST := dist
PYTHON ?= python3
DATA_HOME ?= $(HOME)/.local/share
BIN_DIR ?= $(HOME)/.local/bin

.PHONY: all test collect schemas pack install install-local uninstall clean

all: test

## Run the collector test suite (stdlib unittest, no third-party packages).
test:
	PYTHONPATH=collector:tests $(PYTHON) -m unittest discover -s tests -t tests -v

## Print the collector payload for the current machine.
collect:
	@./bin/aiusages-collect --pretty

## Compile the GSettings schema in place.
schemas:
	glib-compile-schemas $(EXT_DIR)/schemas

## Build dist/$(UUID).shell-extension.zip.
pack: schemas
	mkdir -p $(DIST)
	gnome-extensions pack $(EXT_DIR) \
		--schema=schemas/org.gnome.shell.extensions.aiusages.gschema.xml \
		--extra-source=drawing.js \
		--extra-source=i18n.js \
		--extra-source=panel.js \
		--extra-source=popup.js \
		-f -o $(DIST)

## Install for the current user (~/.local/share + ~/.local/bin).
install: schemas
	./install.sh

install-local: install

uninstall:
	-gnome-extensions disable $(UUID)
	rm -rf "$(DATA_HOME)/gnome-shell/extensions/$(UUID)"
	rm -rf "$(DATA_HOME)/aiusages"
	rm -f "$(BIN_DIR)/aiusages-collect"

clean:
	rm -rf $(DIST)
	find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
