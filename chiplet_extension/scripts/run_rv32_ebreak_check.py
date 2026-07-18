#!/usr/bin/env python3
"""Compile and run the architectural EBREAK trap smoke."""

from __future__ import annotations

import subprocess
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
BUILD = ROOT / "build" / "rv32_ebreak"
REPORT = ROOT / "reports" / "rv32_ebreak_summary.csv"

BUILD.mkdir(parents=True, exist_ok=True)
command = ["verilator", "--binary", "--sv", "--timing", "-Wall", "-Wno-fatal", "-Wno-UNUSEDSIGNAL",
           str(REPO / "base_soc/rtl/pd1_rv32/rv32_core.sv"), str(ROOT / "sim/tb_rv32_ebreak_trap.sv"),
           "--top-module", "tb_rv32_ebreak_trap", "-Mdir", str(BUILD)]
result = subprocess.run(command, capture_output=True, text=True)
(BUILD / "compile.log").write_text(result.stdout + result.stderr)
if result.returncode: raise SystemExit("EBREAK check compile failed")
run = subprocess.run([str(BUILD / "Vtb_rv32_ebreak_trap")], capture_output=True, text=True)
(BUILD / "run.log").write_text(run.stdout + run.stderr)
passed = run.returncode == 0 and "RV32_EBREAK_TRAP_PASS" in run.stdout
REPORT.parent.mkdir(exist_ok=True)
with REPORT.open("w", newline="") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(("test", "status", "expected_cause", "expected_target", "evidence"))
    writer.writerow(("architectural_ebreak_trap", "PASS" if passed else "FAIL", "3", "0x00000300",
                     "EBREAK_TEST_HALT=0 RTL smoke"))
print("Architectural EBREAK trap: PASS" if passed else "Architectural EBREAK trap: FAIL")
raise SystemExit(0 if passed else 1)
