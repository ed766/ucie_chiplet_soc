#!/usr/bin/env python3
"""Validate reviewer documentation structure and local links."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCUMENTS = [ROOT / "README.md", ROOT / "chiplet_extension" / "README.md", *sorted((ROOT / "docs").rglob("*.md"))]
LINK = re.compile(r"!?(?:\[[^]]*\])\(([^)]+)\)")
failures: list[str] = []

for document in DOCUMENTS:
    text = document.read_text()
    relative = document.relative_to(ROOT)
    if "/home/" in text or "/mnt/c/" in text:
        failures.append(f"{relative}: machine-specific path")
    for target in LINK.findall(text):
        target = target.split("#", 1)[0]
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        if not (document.parent / target).resolve().exists():
            failures.append(f"{relative}: missing link {target}")

readme = (ROOT / "README.md").read_text()
if readme.count("<!-- BEGIN GENERATED METRICS -->") != 1 or readme.count("<!-- END GENERATED METRICS -->") != 1:
    failures.append("README.md: expected exactly one generated metric block")
for heading in ("## Verification Snapshot", "## Five-Minute Reviewer Path", "## Architecture"):
    if readme.count(heading) != 1:
        failures.append(f"README.md: expected one {heading!r} heading")
for stale in ("57 / 57", "52 / 52", "UPF scaffolding", "UPF placeholders"):
    if stale in readme:
        failures.append(f"README.md: stale wording {stale!r}")

if failures:
    print("\n".join(f"DOC_CHECK_FAIL|{failure}" for failure in failures))
    raise SystemExit(1)
print(f"DOC_CHECK_PASS|documents={len(DOCUMENTS)}")
