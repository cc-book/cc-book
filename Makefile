BOOK_DIR     := book
BUILD_DIR    := $(BOOK_DIR)/_build
HTML_DIR     := $(BUILD_DIR)/html
PORT         := 3000
CONTENT_PORT := 3100
IMAGE        := cc-book

.DEFAULT_GOAL := help

.PHONY: help install hooks build serve clean rebuild podman-image podman-build podman-serve

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
	@echo "  podman-build  Run 'make build' inside podman, writing output back to this tree"
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

podman-image:
	podman build -t $(IMAGE) -f Containerfile .

# Bind-mounts the repo so 'make build' writes generate_llms.py/jupyter-book
# output straight back to your working tree, no local uv/node install
# required. --userns=keep-id keeps file ownership matching your host user
# (container's "book" user is uid 1000).
podman-build: podman-image
	podman run --rm --userns=keep-id -v $(PWD):/home/book/app:Z -w /home/book/app $(IMAGE) make build

podman-serve: podman-image
	podman run --rm -p 127.0.0.1:$(PORT):$(PORT) -p 127.0.0.1:$(CONTENT_PORT):$(CONTENT_PORT) $(IMAGE)
