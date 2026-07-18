#!/usr/bin/env python3
"""Install the checksum-pinned RV32 GCC/binutils packages without root."""

from __future__ import annotations

import hashlib
import json
import subprocess
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "firmware_c" / "toolchain.lock.json"
BUILD = ROOT / "build" / "rv32_toolchain"


def digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def main() -> int:
    lock = json.loads(LOCK.read_text())
    deb_dir = BUILD / "debs"
    root = BUILD / "root"
    deb_dir.mkdir(parents=True, exist_ok=True)
    root.mkdir(parents=True, exist_ok=True)

    for package in lock["packages"]:
        filename = package["url"].rsplit("/", 1)[1].replace("%2b", "+")
        archive = deb_dir / filename
        if not archive.exists() or digest(archive) != package["sha256"]:
            print(f"Downloading {package['name']} {package['version']}")
            urllib.request.urlretrieve(package["url"], archive)
        actual = digest(archive)
        if actual != package["sha256"]:
            raise SystemExit(
                f"checksum mismatch for {archive.name}: {actual} != {package['sha256']}"
            )
        subprocess.run(["dpkg-deb", "-x", str(archive), str(root)], check=True)
        print(f"Verified {archive.name}: {actual}")

    print(f"Pinned RV32 toolchain installed under {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
