BOOK_DIR     := book
BUILD_DIR    := $(BOOK_DIR)/_build
HTML_DIR     := $(BUILD_DIR)/html
PORT         := 3000
CONTENT_PORT := 3100
IMAGE        := cc-book

.DEFAULT_GOAL := help

.PHONY: help install hooks build serve clean rebuild podman-build podman-serve

help:
	@echo "Confidential Computing Jupyter Book"
	@echo ""
	@echo "Targets:"
	@echo "  install       Install dependencies and git hooks"
	@echo "  hooks         Configure git to use .githooks/"
	@echo "  build         Build the HTML book"
	@echo "  serve         Start the live-preview server (port $(PORT))"
	@echo "  clean         Remove build artefacts"
	@echo "  rebuild       Clean then build"
	@echo "  podman-build  Build the podman container image"
	@echo "  podman-serve  Run the live-preview server in a rootless podman container"

install: hooks
	uv sync

hooks:
	git config core.hooksPath .githooks

build:
	uv run python generate_llms.py
	cd $(BOOK_DIR) && uv run jupyter-book build --html

serve:
	cd $(BOOK_DIR) && uv run jupyter-book start --port $(PORT)

clean:
	rm -rf $(BUILD_DIR)
	@echo "Build artefacts removed."

rebuild: clean build

podman-build:
	podman build -t $(IMAGE) -f Containerfile .

podman-serve: podman-build
	podman run --rm -p $(PORT):$(PORT) -p $(CONTENT_PORT):$(CONTENT_PORT) $(IMAGE)
