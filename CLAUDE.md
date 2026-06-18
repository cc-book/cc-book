# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A technical book — *Confidential Computing Deep Dive* — built with **Jupyter Book 2.x (MyST)** and published to GitHub Pages. The repository is content-first: the "code" is the build tooling, and the substance lives in Markdown chapters. Author/maintainer context: the book is written by a CNCF Confidential Containers maintainer, so claims about CoCo, Trustee, CVMs, and attestation are expected to be technically precise.

## Commands

- `make install` — `uv sync` plus configures git to use `.githooks/` (run once after clone).
- `make build` — runs `generate_llms.py`, then `jupyter-book build --html`. Output in `book/_build/html/`.
- `make serve` — live-preview server on port 3000 (`jupyter-book start`).
- `make rebuild` — `clean` then `build`.

All Python runs through `uv` (e.g. `uv run python generate_llms.py`). Requires Python ≥ 3.11. There is no test suite, linter, or single-test workflow — `main.py` is a placeholder.

## Architecture

The chapter sources are the single source of truth. Three derived artifacts must stay consistent with them and with each other:

1. **`book/myst.yml`** — the `toc:` defines reading order, titles, and nesting for the rendered book.
2. **`generate_llms.py`** — has its own hardcoded `TOC` list (slug, path, title) that produces `book/public/llms.txt`, `book/public/llms-full.txt`, and per-chapter copies in `book/public/chapters/`. **This TOC is maintained separately from `myst.yml`** — when adding, removing, or renaming a chapter you must update both, or the LLM-facing output drifts from the rendered book. (Note: the two TOCs already differ — e.g. `myst.yml` includes the Conclusion and Glossary; `generate_llms.py` does not.)
3. **`book/public/chapters/*.md`** — generated copies, not hand-edited. Edit `book/chapters/*.md`.

Chapters live in `book/chapters/NN_name.md`, numbered for reading order. Images are in `book/images/` — many are `page_NN.png` extracted from a source PDF (hence `pdf2image`/`pymupdf` deps); newer diagrams use descriptive names or inline `{mermaid}` blocks.

## Build/commit flow

- The **pre-commit hook** (`.githooks/pre-commit`) runs `make build` and `git add -A`, so committing regenerates and stages the `public/` LLM artifacts automatically. This only works after `make hooks` (done by `make install`). Expect `book/public/` files to appear in commits even when you only edited a chapter.
- CI (`.github/workflows/publish.yml`) builds with `BASE_URL=/cc-book` and deploys to GitHub Pages on push to `main`.

## Editing conventions

- Chapters use MyST directives: `{figure}`, `{mermaid}`, and admonitions like `:::{warning}`. `generate_llms.py` strips figures/mermaid to `[diagram]` for the LLM text output, so prose should stand on its own without relying on a diagram to convey a key point.
- `extract_description()` pulls the first plain paragraph (skipping headings, tables, lists, blockquotes, images) as each chapter's `llms.txt` summary — keep an informative lead paragraph near the top of every chapter.
