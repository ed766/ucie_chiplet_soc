#!/usr/bin/env python3
"""Build and run standalone C reference-model checks."""

from __future__ import annotations

import csv
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "models" / "flit_crc_ref.c"
BUILD_DIR = ROOT / "build" / "c_reference"
REPORT_CSV = ROOT / "reports" / "c_reference_summary.csv"
REPORT_MD = ROOT.parent / "docs" / "c_reference_model_summary.md"


def main() -> int:
    cc = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang")
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_CSV.parent.mkdir(parents=True, exist_ok=True)
    REPORT_MD.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    status = "SKIP"
    detail = "no_c_compiler_found"
    stdout = ""
    stderr = ""
    binary = BUILD_DIR / "flit_crc_ref"

    if cc:
        compile_cmd = [cc, "-std=c11", "-Wall", "-Wextra", "-Werror", str(MODEL), "-o", str(binary)]
        compile_result = subprocess.run(compile_cmd, cwd=ROOT, capture_output=True, text=True)
        if compile_result.returncode == 0:
            run_result = subprocess.run([str(binary), "--self-test"], cwd=ROOT, capture_output=True, text=True)
            stdout = run_result.stdout.strip()
            stderr = run_result.stderr.strip()
            status = "PASS" if run_result.returncode == 0 else "FAIL"
            detail = stdout if status == "PASS" else (stderr or "self_test_failed")
        else:
            status = "FAIL"
            detail = "compile_failed"
            stdout = compile_result.stdout.strip()
            stderr = compile_result.stderr.strip()

    rows.append(
        {
            "model": "flit_crc_ref",
            "language": "C",
            "status": status,
            "checks": "3" if status == "PASS" else "0",
            "detail": detail,
            "binary": str(binary) if binary.exists() else "",
        }
    )

    with REPORT_CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["model", "language", "status", "checks", "detail", "binary"])
        writer.writeheader()
        writer.writerows(rows)

    REPORT_MD.write_text(
        "\n".join(
            [
                "# C Reference Model Summary",
                "",
                "The chiplet verification flow keeps the Python DMA/AES golden model for full transaction checking and adds a standalone C reference model for the FLIT CRC datapath.",
                "",
                "| Model | Language | Status | Checks | Notes |",
                "| --- | --- | --- | ---: | --- |",
                f"| `flit_crc_ref` | C | {status} | {rows[0]['checks']} | {detail} |",
                "",
                "This is portable regression collateral, not a DPI dependency.",
                "",
            ]
        )
    )

    if stdout:
        print(stdout)
    if stderr:
        print(stderr)
    return 0 if status in {"PASS", "SKIP"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
