#!/usr/bin/env python3
"""Remove machine-specific repository prefixes from checked-in reports."""

from __future__ import annotations

import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(ROOT / "chiplet_extension" / "reports"))
    args = parser.parse_args()

    report_root = Path(args.root).resolve()
    prefix = str(ROOT) + "/"
    changed = 0
    for path in sorted(report_root.rglob("*")):
        if path.suffix not in {".csv", ".md", ".txt"} or not path.is_file():
            continue
        text = path.read_text(errors="replace")
        normalized = text.replace(prefix, "")
        if normalized != text:
            path.write_text(normalized)
            changed += 1
    print(f"Normalized repository paths in {changed} report files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
