# Confidential Computing Deep Dive

A technical book on Confidential Computing, TEEs, and CNCF Confidential
Containers, built with [Jupyter Book](https://jupyterbook.org/) (MyST) and
published to GitHub Pages.

## Building locally

Requires Python >= 3.11 and [uv](https://docs.astral.sh/uv/).

```
make install   # uv sync + configure git hooks (run once after clone)
make build     # generate LLM artifacts, build the HTML book
make serve     # live-preview server at http://localhost:3000
```

Run `make help` for the full list of targets.

## Building with podman

To build and serve the book from a container instead of a local Python/Node
setup (works with rootless podman):

```
make podman-build   # build the container image
make podman-serve   # serve the live-preview site at http://localhost:3000
```
