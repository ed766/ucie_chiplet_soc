#!/usr/bin/env python3
"""Require each RV32M RTL mutation to fail its focused executable check."""

from __future__ import annotations

import csv
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
REPO=ROOT.parent
BUILD=ROOT/"build/rv32m_mutations"
REPORT=ROOT/"reports/rv32m_mutation_summary.csv"
MUTATIONS=(
  ("RV32_BUG_M_HIGH_PRODUCT","unit","high_product"),
  ("RV32_BUG_MULHSU_SIGNEDNESS","unit","mixed_signedness"),
  ("RV32_BUG_M_DIV_ROUND","unit","quotient_rounding"),
  ("RV32_BUG_M_REM_SIGN","unit","remainder_sign"),
  ("RV32_BUG_M_DIV_ZERO","unit","divide_zero"),
  ("RV32_BUG_M_DIV_OVERFLOW","unit","signed_overflow"),
  ("RV32_BUG_M_EARLY_RETIRE","core","retirement_order"),
  ("RV32_BUG_M_STALE_RESET","unit","reset_cancellation"),
)
def main()->int:
  shutil.rmtree(BUILD,ignore_errors=True);BUILD.mkdir(parents=True);rows=[]
  for mutation,kind,bucket in MUTATIONS:
    obj=BUILD/mutation.lower();tb=ROOT/"sim"/("tb_rv32m_core.sv" if kind=="core" else "tb_rv32_muldiv.sv")
    command=["verilator","--binary","--sv","--timing","-Wall","-Wno-fatal","-Wno-PINMISSING",
      "-Wno-WIDTH","-Wno-UNUSEDSIGNAL","-Wno-BLKSEQ",f"+define+{mutation}",
      str(REPO/"base_soc/rtl/pd1_rv32/rv32_muldiv.sv")]
    if kind=="core":command.append(str(REPO/"base_soc/rtl/pd1_rv32/rv32_core.sv"))
    command.extend([str(tb),"--top-module","tb_rv32m_core" if kind=="core" else "tb_rv32_muldiv","-Mdir",str(obj)])
    compiled=subprocess.run(command,capture_output=True,text=True)
    if compiled.returncode:run=compiled
    else:
      executable=obj/("Vtb_rv32m_core" if kind=="core" else "Vtb_rv32_muldiv")
      run=subprocess.run([str(executable)],capture_output=True,text=True,timeout=20)
    detected=compiled.returncode==0 and run.returncode!=0
    (BUILD/f"{mutation}.log").write_text(compiled.stdout+compiled.stderr+run.stdout+run.stderr)
    rows.append({"mutation":mutation,"kind":"RTL_MUTATION","expected_bucket":bucket,
      "compile_status":"PASS" if compiled.returncode==0 else "FAIL","detected":int(detected),
      "status":"PASS" if detected else "FAIL"})
  REPORT.parent.mkdir(exist_ok=True)
  with REPORT.open("w",newline="")as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator="\n");writer.writeheader();writer.writerows(rows)
  passed=sum(row["status"]=="PASS" for row in rows);print(f"RV32M RTL mutations: {passed} / {len(rows)} detected")
  return 0 if passed==len(rows) else 1
if __name__=="__main__":raise SystemExit(main())
