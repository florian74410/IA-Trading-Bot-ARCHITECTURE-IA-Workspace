#!/usr/bin/env python3
"""Dependency-free safety and smoke checks for the static Architecture site."""
from pathlib import Path
from html.parser import HTMLParser
import sys

class Scan(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.duplicate_ids = set()
        self.title = False
        self.scripts = 0
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            (self.duplicate_ids if a["id"] in self.ids else self.ids).add(a["id"])
        if tag == "title":
            self.title = True
        if tag == "script":
            self.scripts += 1

def main():
    site = Path(__file__).resolve().parent.parent / "site"
    if not site.is_dir() or not (site / "index.html").is_file():
        sys.exit("FAIL: site/index.html missing")
    files = list(site.rglob("*"))
    if any(p.is_symlink() for p in files):
        sys.exit("FAIL: symlink forbidden in site")
    if any(p.is_file() and p.stat().st_size > 2_000_000 for p in files):
        sys.exit("FAIL: site file exceeds 2 MB")
    html = (site / "index.html").read_text(encoding="utf-8")
    scan = Scan()
    scan.feed(html)
    if not scan.title or not html.lower().startswith("<!doctype html"):
        sys.exit("FAIL: missing HTML doctype/title")
    if scan.duplicate_ids:
        sys.exit("FAIL: duplicate HTML ids: " + ", ".join(sorted(scan.duplicate_ids)))
    if "IA-TB" not in html or "Architecture" not in html:
        sys.exit("FAIL: expected Architecture identity missing")
    print(f"PASS: static site validation ({len(files)} entries, {len(scan.ids)} HTML IDs)")

if __name__ == "__main__":
    main()
