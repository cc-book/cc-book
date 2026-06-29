"""Generate llms.txt and llms-full.txt for LLM-friendly access to the book."""

import re
from pathlib import Path

BOOK_DIR = Path("book")
PUBLIC_DIR = BOOK_DIR / "public"
CHAPTERS_DIR = BOOK_DIR / "chapters"

SITE_URL = "https://cc-book.github.io/cc-book"

# TOC in reading order — mostly matches myst.yml but intentionally diverges:
# Conclusion, Glossary, and References are excluded because they contain no
# substantive technical content needed by LLMs parsing the book.
TOC = [
    ("intro",              BOOK_DIR / "intro.md",                       "Introduction"),
    ("trust-boundary",     CHAPTERS_DIR / "01_trust_boundary.md",       "The Trust Boundary Problem"),
    ("overview",           CHAPTERS_DIR / "02_overview.md",             "What is Confidential Computing?"),
    ("use-cases",          CHAPTERS_DIR / "03_use_cases.md",            "Use Cases"),
    ("building-blocks",    CHAPTERS_DIR / "04_building_blocks.md",      "Building Blocks"),
    ("remote-attestation", CHAPTERS_DIR / "05_remote_attestation.md",   "Remote Attestation"),
    ("three-pillars",      CHAPTERS_DIR / "06_three_pillars.md",        "Three Pillars of Confidential Computing"),
    ("confidential-vms",   CHAPTERS_DIR / "07_confidential_vms.md",     "Confidential Virtual Machine (CVM)"),
    ("confidential-containers", CHAPTERS_DIR / "09_confidential_containers.md", "Confidential Containers (CoCo)"),
    ("confidential-clusters", CHAPTERS_DIR / "10_confidential_clusters.md", "Confidential Cluster"),
    ("trustee",            CHAPTERS_DIR / "11_trustee.md",              "Trustee"),
    ("labs",               CHAPTERS_DIR / "12_labs.md",                 "Hands-On Labs"),
    ("lab1-cvm-attestation", CHAPTERS_DIR / "12_lab1_cvm_attestation.md", "Lab 1: CVM Attestation on Azure"),
    ("lab2-coco-without-hw", CHAPTERS_DIR / "12_lab2_coco_without_hw.md", "Lab 2: CoCo Without Confidential Hardware"),
    ("lab3-cococtl",       CHAPTERS_DIR / "12_lab3_cococtl.md",         "Lab 3: CoCo-fy a Workload with cococtl"),
    ("lab4-byom",          CHAPTERS_DIR / "12_lab4_byom.md",            "Lab 4: CoCo on a Real CVM via Peer-Pods (BYOM)"),
    ("references",         CHAPTERS_DIR / "13_references.md",           "References"),
]


def extract_description(path: Path) -> str:
    """Return the first non-empty non-heading paragraph from a markdown file."""
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and not line.startswith("```") \
                and not line.startswith("---") and not line.startswith("|") \
                and not line.startswith(">") and not line.startswith("*") \
                and not line.startswith("!"):
            # Strip markdown bold/italic
            line = re.sub(r"\*+([^*]+)\*+", r"\1", line)
            return line[:200]
    return ""


def strip_mermaid_and_figures(text: str) -> str:
    """Replace mermaid/figure blocks with a placeholder so LLMs get clean text."""
    # Remove figure directives
    text = re.sub(r"```\{figure\}.*?```", "[diagram]", text, flags=re.DOTALL)
    # Remove mermaid blocks
    text = re.sub(r"```\{mermaid\}.*?```", "[diagram]", text, flags=re.DOTALL)
    # Remove raw code fences used for ASCII art (no language tag)
    text = re.sub(r"```\n[┌│└├─►◄→←↑↓\s]+```", "[diagram]", text, flags=re.DOTALL)
    return text


def build_llms_txt() -> str:
    lines = [
        f"# Confidential Computing Deep Dive",
        f"",
        f"> A comprehensive guide to Confidential Computing, TEEs, attestation,",
        f"> Confidential VMs, and CNCF Confidential Containers (CoCo).",
        f"> Author: Pradipta Banerjee, Project Maintainer — Confidential Containers",
        f"",
        f"## Chapters",
        f"",
    ]
    for slug, path, title in TOC:
        desc = extract_description(path)
        url = f"{SITE_URL}/chapters/{slug}.md"
        lines.append(f"- [{title}]({url}): {desc}")

    lines += [
        f"",
        f"## Full book (single file)",
        f"",
        f"- [llms-full.txt]({SITE_URL}/llms-full.txt): All chapters concatenated into one document.",
    ]
    return "\n".join(lines) + "\n"


def build_llms_full_txt() -> str:
    parts = [
        "# Confidential Computing Deep Dive",
        "Author: Pradipta Banerjee, Project Maintainer — Confidential Containers",
        "Source: https://cc-book.github.io/cc-book/",
        "",
        "---",
        "",
    ]
    for _slug, path, title in TOC:
        raw = path.read_text(encoding="utf-8")
        clean = strip_mermaid_and_figures(raw)
        parts.append(clean)
        parts.append("\n---\n")
    return "\n".join(parts)


def copy_chapter_markdown() -> None:
    """Copy source markdown files to public/chapters/ for per-page raw access."""
    out_dir = PUBLIC_DIR / "chapters"
    out_dir.mkdir(parents=True, exist_ok=True)
    for slug, path, _title in TOC:
        dest = out_dir / f"{slug}.md"
        dest.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")


if __name__ == "__main__":
    PUBLIC_DIR.mkdir(parents=True, exist_ok=True)

    (PUBLIC_DIR / "llms.txt").write_text(build_llms_txt(), encoding="utf-8")
    print("  Written: public/llms.txt")

    (PUBLIC_DIR / "llms-full.txt").write_text(build_llms_full_txt(), encoding="utf-8")
    print("  Written: public/llms-full.txt")

    copy_chapter_markdown()
    print("  Written: public/chapters/<slug>.md for each chapter")
