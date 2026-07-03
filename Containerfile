FROM python:3.11-slim

# jupyter-book (mystmd) needs Node 18/20/22+ on PATH
RUN apt-get update && apt-get install -y --no-install-recommends nodejs npm \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

# Rootless podman: avoid running as container root
RUN useradd --create-home --uid 1000 book
WORKDIR /home/book/app
COPY --chown=book:book . .
USER book

RUN uv sync --frozen

# 3000: book site, 3100: content/asset server (images, CSS) the page fetches from the browser
EXPOSE 3000 3100
WORKDIR /home/book/app/book
ENV HOST=0.0.0.0
CMD ["uv", "run", "jupyter-book", "start", "--port", "3000", "--keep-host"]
