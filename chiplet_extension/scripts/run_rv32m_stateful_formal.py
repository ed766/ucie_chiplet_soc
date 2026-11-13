#!/usr/bin/env python3
"""Expanded core-control bounded check; abstract arithmetic, real core control."""
import csv
import hashlib
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "formal/rv32m"
OUT = ROOT / "build/rv32m_stateful_core"
LOCK = ROOT / "build/external_riscv_tools/environment.sh"

def main():
    if not LOCK.is_file(): raise SystemExit("missing required pinned formal tool environment")
    run = subprocess.run(["bash", "-c", f"source {LOCK} && sby -f -d {OUT} rv32m_stateful_core.sby"], cwd=WORK, capture_output=True, text=True)
    if OUT.is_dir(): (OUT / "runner.log").write_text(run.stdout + run.stderr)
    status = (OUT / "status").read_text().strip().split()[0] if (OUT / "status").is_file() else "FAIL"
    cover_out=ROOT/"build/rv32m_stateful_core_cover"
    cover_run=subprocess.run(["bash","-c",f"source {LOCK} && sby -f -d {cover_out} rv32m_stateful_core_cover.sby"],cwd=WORK,capture_output=True,text=True)
    cover_status=(cover_out/"status").read_text().strip().split()[0] if (cover_out/"status").is_file() else "FAIL"
    row = dict(group="stateful_core_control", mode="bounded_safety", depth=50,
               status="PASS" if run.returncode == 0 and status == "PASS" else "FAIL",
               environment="arbitrary issue, nonzero/aliased registers, external/timer IRQ and mid-operation reset",
               arithmetic="assume-guarantee muldiv response contract; not arithmetic equivalence",
               cover_status="REACHABLE" if cover_run.returncode==0 and cover_status=="PASS" else "FAIL",
               harness_sha256=hashlib.sha256((WORK / "rv32m_stateful_core.sv").read_bytes()).hexdigest())
    with (ROOT / "reports/rv32m_stateful_formal.csv").open("w", newline="") as handle:
        writer=csv.DictWriter(handle,fieldnames=row,lineterminator="\n"); writer.writeheader(); writer.writerow(row)
    print(f"RV32M stateful core-control BMC: {row['status']} depth=50; covers {row['cover_status']}")
    return int(row["status"] != "PASS" or row["cover_status"] != "REACHABLE")

if __name__ == "__main__": raise SystemExit(main())
