#!/usr/bin/env python3
"""Validate pinned external RISC-V dependencies without overstating results."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "verification" / "external_riscv_tools.lock.json"
REPORT = ROOT / "reports" / "rv32_external_tool_status.csv"


def git_revision(path: Path) -> str:
    result = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"], capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else ""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true")
    args = parser.parse_args()
    lock = json.loads(LOCK.read_text())
    env_paths = {
        "spike": os.environ.get("SPIKE_HOME", ""),
        "riscv-act": os.environ.get("RISCV_ACT_HOME", ""),
        "riscv-formal": os.environ.get("RISCV_FORMAL_HOME", ""),
    }
    executables = {"spike": "spike", "sail-riscv": "sail_riscv_sim",
                   "mise": "mise", "act4-gcc": "riscv-none-elf-gcc",
                   "oss-cad-suite": "sby"}
    archives = {
        "sail-riscv": os.environ.get("SAIL_RISCV_ARCHIVE", ""),
        "mise": os.environ.get("MISE_ARCHIVE", ""),
        "act4-gcc": os.environ.get("ACT4_GCC_ARCHIVE", ""),
        "oss-cad-suite": os.environ.get("OSS_CAD_SUITE_ARCHIVE", ""),
    }
    rows = []
    for tool in lock["tools"]:
        name = tool["name"]
        status, observed, detail = "SKIP", "", "dependency_not_installed"
        if name in env_paths:
            path = Path(env_paths[name]) if env_paths.get(name) else None
            if path and path.exists():
                observed = git_revision(path)
                expected = tool["revision"]
                executable = shutil.which(executables[name]) if name in executables else True
                status = "PASS" if observed == expected and executable else "FAIL"
                detail = "revision_match" if status == "PASS" else "revision_mismatch"
        elif name in archives:
            archive = Path(archives[name]) if archives.get(name) else None
            executable = shutil.which(executables[name])
            if archive and archive.exists() and executable:
                observed = sha256(archive)
                status = "PASS" if observed == tool["sha256"] else "FAIL"
                detail = "archive_checksum_match" if status == "PASS" else "archive_checksum_mismatch"
        rows.append({"tool": name, "status": status, "expected": tool.get("revision", tool.get("version", "")),
                     "observed": observed, "detail": detail})
    REPORT.parent.mkdir(exist_ok=True)
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    skipped = sum(row["status"] == "SKIP" for row in rows)
    failed = sum(row["status"] == "FAIL" for row in rows)
    print(f"External RISC-V tools: {passed} PASS, {skipped} SKIP, {failed} FAIL")
    return 1 if failed or (args.require and passed != len(rows)) else 0


if __name__ == "__main__":
    raise SystemExit(main())
