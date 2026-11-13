#!/usr/bin/env python3
"""Require each RV32M RTL mutation to fail its focused executable check."""

from __future__ import annotations

import csv
import re
import shutil
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
REPO=ROOT.parent
BUILD=ROOT/"build/rv32m_mutations"
REPORT=ROOT/"reports/rv32m_mutation_summary.csv"
MUTATIONS=(
  ("RV32_BUG_M_HIGH_PRODUCT","unit","high_product","mulh_signed"),
  ("RV32_BUG_MULHSU_SIGNEDNESS","unit","mixed_signedness","mulhsu_mixed"),
  ("RV32_BUG_M_DIV_ROUND","unit","quotient_rounding","div_signed"),
  ("RV32_BUG_M_REM_SIGN","unit","remainder_sign","rem_signed"),
  ("RV32_BUG_M_DIV_ZERO","unit","divide_zero","div_by_zero"),
  ("RV32_BUG_M_DIV_OVERFLOW","unit","signed_overflow","div_overflow"),
  ("RV32_BUG_M_EARLY_RETIRE","core","retirement_order","core_retirement"),
  ("RV32_BUG_M_STALE_RESET","unit","reset_cancellation","reset_cancellation"),
)

def qualified_failure(compiled, returncode, output, activation, nominal_pass):
  failures = re.findall(r"RV32M_FAILURE\|([a-z0-9_]+)\|", output)
  reached = f"RV32M_ACTIVATE|{activation}" in output
  return bool(compiled and nominal_pass and returncode != 0 and reached and failures == [activation])

def main()->int:
  shutil.rmtree(BUILD,ignore_errors=True);BUILD.mkdir(parents=True);rows=[]
  controls={}
  jobs=[("NOMINAL_UNIT","unit","control","", ""), ("NOMINAL_CORE","core","control","", "")]
  jobs.extend((*row, row[0]) for row in MUTATIONS)
  for mutation,kind,bucket,activation,define in jobs:
    obj=BUILD/mutation.lower();tb=ROOT/"sim"/("tb_rv32m_core.sv" if kind=="core" else "tb_rv32_muldiv.sv")
    command=["verilator","--binary","--sv","--timing","-Wall","-Wno-fatal","-Wno-PINMISSING",
      "-Wno-WIDTH","-Wno-UNUSEDSIGNAL","-Wno-BLKSEQ",
      str(REPO/"base_soc/rtl/pd1_rv32/rv32_muldiv.sv")]
    if define:command.append(f"+define+{define}")
    if kind=="core":command.append(str(REPO/"base_soc/rtl/pd1_rv32/rv32_core.sv"))
    command.extend([str(tb),"--top-module","tb_rv32m_core" if kind=="core" else "tb_rv32_muldiv","-Mdir",str(obj)])
    compiled=subprocess.run(command,capture_output=True,text=True)
    if compiled.returncode:run=compiled
    else:
      executable=obj/("Vtb_rv32m_core" if kind=="core" else "Vtb_rv32_muldiv")
      try:
        run=subprocess.run([str(executable)],capture_output=True,text=True,timeout=20)
      except subprocess.TimeoutExpired:
        run=subprocess.CompletedProcess([],124,"","runner timeout: unqualified failure")
    (BUILD/f"{mutation}.log").write_text(compiled.stdout+compiled.stderr+run.stdout+run.stderr)
    output=run.stdout+run.stderr
    if not define:
      marker="RV32M_CORE_SUMMARY|status=PASS" if kind=="core" else "RV32M_SUMMARY|72|72|PASS"
      controls[kind]=compiled.returncode==0 and run.returncode==0 and marker in output
      continue
    detected=qualified_failure(compiled.returncode==0,run.returncode,output,activation,controls.get(kind,False))
    rows.append({"mutation":mutation,"kind":"RTL_MUTATION","expected_bucket":bucket,
      "activation":activation,"activation_reached":int(f"RV32M_ACTIVATE|{activation}" in output),
      "observed_failure":';'.join(re.findall(r"RV32M_FAILURE\|([a-z0-9_]+)\|",output)),
      "nominal_control":"PASS" if controls.get(kind,False) else "FAIL",
      "compile_status":"PASS" if compiled.returncode==0 else "FAIL","detected":int(detected),
      "status":"PASS" if detected else "FAIL"})
  REPORT.parent.mkdir(exist_ok=True)
  with REPORT.open("w",newline="")as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator="\n");writer.writeheader();writer.writerows(rows)
  passed=sum(row["status"]=="PASS" for row in rows);print(f"RV32M RTL mutations: {passed} / {len(rows)} detected")
  return 0 if passed==len(rows) else 1
if __name__=="__main__":raise SystemExit(main())
