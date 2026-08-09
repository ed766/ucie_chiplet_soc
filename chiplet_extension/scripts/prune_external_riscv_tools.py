#!/usr/bin/env python3
"""Remove verified external-tool downloads and build intermediates before CI simulation."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INSTALL = ROOT / "build" / "external_riscv_tools"


def tree_size(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install-dir", type=Path, default=DEFAULT_INSTALL)
    args = parser.parse_args()
    install = args.install_dir.resolve()
    removable = (install / "archives", install / "spike-src" / "build-codex")
    reclaimed = sum(tree_size(path) for path in removable)
    for path in removable:
        shutil.rmtree(path, ignore_errors=True)
    print(f"Pruned verified external-tool intermediates: {reclaimed / (1024 ** 3):.2f} GiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
