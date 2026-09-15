#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "chiplet_extension/build/rv32_external_window"

BUILD.mkdir(parents=True, exist_ok=True)
cmd = [
    "verilator", "--binary", "--sv", "--timing", "--assert",
    "-Wall", "-Wno-fatal", "--top-module", "tb_rv32_external_window",
    "--Mdir", str(BUILD / "obj"),
    str(ROOT / "base_soc/rtl/pd1_rv32/rv32_muldiv.sv"),
    str(ROOT / "base_soc/rtl/pd1_rv32/rv32_core.sv"),
    str(ROOT / "chiplet_extension/sim/tb_rv32_external_window.sv"),
]
subprocess.run(cmd, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
run = subprocess.run(
    [str(BUILD / "obj/Vtb_rv32_external_window")], cwd=ROOT,
    check=True, text=True, capture_output=True
)
if "RV32_EXTERNAL_WINDOW|status=PASS" not in run.stdout:
    raise SystemExit("external-memory window did not report PASS")
print("RV32 external-memory window: PASS")
