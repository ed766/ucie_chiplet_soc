#!/usr/bin/env python3
"""Compile and run the optional multi-clock chiplet CDC matrix."""

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "async_cdc"
REPORT = ROOT / "reports" / "async_cdc_summary.csv"
RATIOS = ((5, 5, 0), (5, 7, 1), (3, 5, 2), (5, 2, 3))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verilator", default="verilator")
    args = parser.parse_args()
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)
    sources = [ROOT / "sim" / "tb_async_chiplet.sv", *sorted((ROOT / "rtl").rglob("*.sv"))]
    cmd = [
        args.verilator, "--binary", "--sv", "--timing", "-Wall", "-Wno-fatal",
        "-Wno-DECLFILENAME", "-Wno-PINCONNECTEMPTY", "-Wno-WIDTHEXPAND",
        "-Wno-UNUSEDSIGNAL", "-Wno-UNUSEDPARAM", "--top-module", "tb_async_chiplet",
        "-Mdir", str(BUILD / "obj"), *map(str, sources),
    ]
    compiled = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    (BUILD / "compile.log").write_text(compiled.stdout + compiled.stderr)
    if compiled.returncode:
        print(f"Async CDC compile failed; see {BUILD / 'compile.log'}")
        return 1
    binary = BUILD / "obj" / "Vtb_async_chiplet"
    rows = []
    for a_half, b_half, skew in RATIOS:
        run = subprocess.run(
            [str(binary), f"+A_HALF={a_half}", f"+B_HALF={b_half}", f"+RESET_SKEW={skew}"],
            cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
        log = BUILD / f"ratio_{a_half}_{b_half}_skew_{skew}.log"
        log.write_text(run.stdout + run.stderr)
        passed = run.returncode == 0 and "ASYNC_RESULT|status=PASS" in run.stdout
        rows.append({
            "clock_ratio": f"{a_half}:{b_half}", "reset_skew": skew,
            "status": "PASS" if passed else "FAIL",
            "log": str(log.relative_to(ROOT.parent)),
        })
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"Async CDC matrix: {passed}/{len(rows)}; report={REPORT.relative_to(ROOT.parent)}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
