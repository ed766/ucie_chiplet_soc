#!/usr/bin/env python3
"""Locate the external RV32 GCC/binutils toolchain used by compiled firmware."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def tool(name: str) -> str:
    explicit = os.environ.get("RISCV_TOOLCHAIN_PREFIX")
    prefixes = [explicit] if explicit else []
    prefixes.extend(["riscv64-unknown-elf-", "riscv32-unknown-elf-"])
    local = ROOT / "build" / "rv32_toolchain" / "root" / "usr" / "bin"
    for prefix in prefixes:
        if not prefix:
            continue
        candidate = f"{prefix}{name}"
        found = shutil.which(candidate)
        if found:
            return found
        local_candidate = local / Path(candidate).name
        if local_candidate.is_file():
            return str(local_candidate)
    raise FileNotFoundError(
        f"missing RISC-V tool '{name}'; install gcc-riscv64-unknown-elf and "
        "binutils-riscv64-unknown-elf, or set RISCV_TOOLCHAIN_PREFIX"
    )
