BOOK_DIR  := book
BUILD_DIR := $(BOOK_DIR)/_build
HTML_DIR  := $(BUILD_DIR)/html
PORT      := 3000

.DEFAULT_GOAL := help

.PHONY: help install hooks build serve clean rebuild

help:
	@echo "Confidential Computing Jupyter Book"
	@echo ""
	@echo "Targets:"
	@echo "  install   Install dependencies and git hooks"
	@echo "  hooks     Configure git to use .githooks/"
	@echo "  build     Build the HTML book"
	@echo "  serve     Start the live-preview server (port $(PORT))"
	@echo "  clean     Remove build artefacts"
	@echo "  rebuild   Clean then build"

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
