BOOK_DIR  := book
BUILD_DIR := $(BOOK_DIR)/_build
PORT      := 3000

.DEFAULT_GOAL := help

.PHONY: help install build serve clean rebuild

help:
	@echo "Confidential Computing Jupyter Book"
	@echo ""
	@echo "Targets:"
	@echo "  install   Install dependencies via uv"
	@echo "  build     Build the HTML book"
	@echo "  serve     Start the live-preview server (port $(PORT))"
	@echo "  clean     Remove build artefacts"
	@echo "  rebuild   Clean then build"

install:
	uv sync

build:
	cd $(BOOK_DIR) && uv run jupyter-book build

serve:
	cd $(BOOK_DIR) && uv run jupyter-book start --port $(PORT)

clean:
	rm -rf $(BUILD_DIR)
	@echo "Build artefacts removed."

rebuild: clean build
