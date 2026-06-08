#!/usr/bin/env python3
"""
Mirror a Docsify documentation site into local markdown files for AI/local use.

Usage:
  python3 scripts/tools/mirror_docsify_docs.py \
    https://docs.paytsoftware.com/ \
    /Users/developer-cloudprimero/Desktop/Godot/local-docs/paytsoftware
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path


LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
IMAGE_RE = re.compile(r"!\[[^\]]*\]\(([^)\s]+)")


def fetch_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8", "ignore")


def fetch_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read()


def docsify_route_to_md_url(base_url: str, route: str) -> str:
    route = route.strip().lstrip("/")
    if not route or route == "#":
        route = "README"
    if not route.endswith(".md"):
        route = route + ".md"
    return urllib.parse.urljoin(base_url, route)


def is_relative_docs_link(link: str) -> bool:
    if not link or link.startswith("#"):
        return False
    parsed = urllib.parse.urlparse(link)
    return not parsed.scheme and not link.startswith("//")


def sanitize_route_to_path(route: str) -> Path:
    route = route.strip().lstrip("/")
    if not route or route == "#":
        return Path("README.md")
    if route.endswith("/"):
        route = route[:-1]
    if not route.endswith(".md"):
        route = route + ".md"
    return Path(route)


def mirror_docsify(base_url: str, output_dir: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)

    sidebar_url = urllib.parse.urljoin(base_url, "_sidebar.md")
    sidebar = fetch_text(sidebar_url)
    (output_dir / "_sidebar.md").write_text(sidebar, encoding="utf-8")

    mirrored: list[Path] = []
    seen_routes: set[str] = set()

    for raw_link in LINK_RE.findall(sidebar):
        if not is_relative_docs_link(raw_link):
            continue
        route = raw_link.split("#", 1)[0]
        if not route or route in seen_routes:
            continue
        seen_routes.add(route)

        target_path = output_dir / sanitize_route_to_path(route)
        target_path.parent.mkdir(parents=True, exist_ok=True)

        md_url = docsify_route_to_md_url(base_url, route)
        text = fetch_text(md_url)
        target_path.write_text(text, encoding="utf-8")
        mirrored.append(target_path)

        for img_link in IMAGE_RE.findall(text):
            parsed = urllib.parse.urlparse(img_link)
            if parsed.scheme or img_link.startswith("//"):
                continue
            asset_url = urllib.parse.urljoin(md_url, img_link)
            asset_path = output_dir / Path(urllib.parse.urlparse(img_link).path.lstrip("/"))
            asset_path.parent.mkdir(parents=True, exist_ok=True)
            if not asset_path.exists():
                asset_path.write_bytes(fetch_bytes(asset_url))

    return mirrored


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base_url")
    parser.add_argument("output_dir")
    args = parser.parse_args()

    base_url = args.base_url
    if not base_url.endswith("/"):
        base_url += "/"

    output_dir = Path(args.output_dir)
    mirrored = mirror_docsify(base_url, output_dir)
    print(f"Mirrored {len(mirrored)} markdown files into {output_dir}")
    for path in mirrored:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
