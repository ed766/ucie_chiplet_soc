#!/usr/bin/env python3
"""Compile the iterative RV32M unit and emit canonical directed results."""

from __future__ import annotations

import csv
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
BUILD = ROOT / "build" / "rv32m_unit"
REPORT = ROOT / "reports" / "rv32m_directed_summary.csv"

shutil.rmtree(BUILD, ignore_errors=True)
BUILD.mkdir(parents=True)
command = [
    "verilator", "--binary", "--sv", "--timing", "-Wall", "-Wno-fatal",
    str(REPO / "base_soc/rtl/pd1_rv32/rv32_muldiv.sv"),
    str(ROOT / "sim/tb_rv32_muldiv.sv"),
    "--top-module", "tb_rv32_muldiv", "-Mdir", str(BUILD),
]
compiled = subprocess.run(command, capture_output=True, text=True)
(BUILD / "compile.log").write_text(compiled.stdout + compiled.stderr)
if compiled.returncode:
    raise SystemExit("RV32M unit compile failed; see build/rv32m_unit/compile.log")

run = subprocess.run([str(BUILD / "Vtb_rv32_muldiv")], capture_output=True, text=True)
(BUILD / "run.log").write_text(run.stdout + run.stderr)
pattern = re.compile(r"RV32M_TEST\|([^|]+)\|([^|]+)\|(\d+)")
rows = [(name, status, latency) for name, status, latency in pattern.findall(run.stdout)]
directed_rows = [row for row in rows if not row[0].startswith("coverage_")]
REPORT.parent.mkdir(exist_ok=True)
with REPORT.open("w", newline="") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(("test", "status", "latency_cycles", "evidence"))
    for name, status, latency in directed_rows:
        writer.writerow((name, status, latency, "rv32_muldiv handshake simulation"))
passed = sum(status == "PASS" for _, status, _ in directed_rows)
print(f"RV32M directed: {passed} / 24 PASS")
if run.returncode or len(directed_rows) != 24 or passed != 24:
    raise SystemExit("RV32M directed verification failed")
coverage = set(re.findall(r"RV32M_COVER\|(\d)\|([^\n\r]+)", run.stdout))
with (ROOT / "reports" / "rv32m_coverage_summary.csv").open("w", newline="") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(("operation", "operand_class", "status", "evidence"))
    for op in range(8):
        for operand_class in ("zero", "one", "all_ones", "signed_min", "power_two", "other"):
            writer.writerow((op, operand_class, "COVERED" if (str(op), operand_class) in coverage else "MISSING",
                             "rv32_muldiv accepted transaction"))
if len(coverage) != 48:
    raise SystemExit(f"RV32M arithmetic coverage incomplete: {len(coverage)} / 48")
print("RV32M arithmetic coverage: 48 / 48")

core_build = BUILD / "core"
core_build.mkdir()
core_command = [
    "verilator", "--binary", "--sv", "--timing", "-Wall", "-Wno-fatal",
    "-Wno-PINMISSING", "-Wno-WIDTH", "-Wno-UNUSEDSIGNAL", "-Wno-BLKSEQ",
    str(REPO / "base_soc/rtl/pd1_rv32/rv32_muldiv.sv"),
    str(REPO / "base_soc/rtl/pd1_rv32/rv32_core.sv"),
    str(ROOT / "sim/tb_rv32m_core.sv"),
    "--top-module", "tb_rv32m_core", "-Mdir", str(core_build),
]
compiled = subprocess.run(core_command, capture_output=True, text=True)
(core_build / "compile.log").write_text(compiled.stdout + compiled.stderr)
if compiled.returncode:
    raise SystemExit("RV32M core compile failed; see build/rv32m_unit/core/compile.log")
run = subprocess.run([str(core_build / "Vtb_rv32m_core")], capture_output=True, text=True)
(core_build / "run.log").write_text(run.stdout + run.stderr)
if run.returncode or "RV32M_CORE_SUMMARY|status=PASS" not in run.stdout:
    raise SystemExit("RV32M core integration failed")
print("RV32M core integration: PASS")
