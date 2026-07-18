#!/usr/bin/env python3
"""Preflight the external tools used by the compiled-C firmware lane."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

from rv32_toolchain import tool


ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "firmware_c" / "toolchain.lock.json"


def main() -> int:
    lock = json.loads(LOCK.read_text())
    expected = {package["name"]: package["version"] for package in lock["packages"]}
    versions: list[str] = []
    for name in ("gcc", "objcopy", "objdump"):
        executable = tool(name)
        first = subprocess.run(
            [executable, "--version"], check=True, capture_output=True, text=True
        ).stdout.splitlines()[0]
        package = "gcc-riscv64-unknown-elf" if name == "gcc" else "binutils-riscv64-unknown-elf"
        if expected[package] not in first:
            raise SystemExit(
                f"{name} version does not match toolchain.lock.json: {first}; "
                f"expected package version {expected[package]}"
            )
        versions.append(f"{name}: {first}")
    print("RV32 toolchain preflight PASS")
    print(f"target: {lock['target']}; lock schema: {lock['schema']}")
    print("\n".join(versions))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
