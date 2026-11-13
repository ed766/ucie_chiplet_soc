#!/usr/bin/env python3
"""Run solver-backed RV32M protocol proofs and reachability covers."""

from __future__ import annotations

import csv
import os
import shutil
import subprocess
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
FORMAL=ROOT/"formal/rv32m"
BUILD=ROOT/"build/rv32m_formal"
REPORT=ROOT/"reports/rv32m_formal_summary.csv"
TASKS=(("rv32_muldiv_prove.sby","muldiv_protocol","bounded_safety","prove",84,"solver_backed_bmc_z3"),
       ("rv32_muldiv_cover.sby","opcode_reachability","cover","cover",84,"solver_backed_cover_z3"),
       ("rv32m_core_prove.sby","core_retirement_contract","bounded_safety","core_prove",50,"solver_backed_bmc_abc_abstract_unit_zero_operands"),
       ("rv32m_core_cover.sby","core_retirement_reachability","cover","core_cover",50,"solver_backed_cover_z3_abstract_unit_zero_operands"))

def main()->int:
  candidates=[shutil.which("sby"),str(Path.home()/".cache/oss-cad-suite/bin/sby")]
  sby=next((item for item in candidates if item and Path(item).exists()),None)
  rows=[]
  if not sby:
    rows=[{"group":name,"mode":mode,"status":"SKIP","depth":depth,"runtime_seconds":"0.000","detail":"sby_unavailable"}
          for config,name,mode,dirname,depth,detail in TASKS]
  else:
    shutil.rmtree(BUILD,ignore_errors=True);BUILD.mkdir(parents=True)
    env=os.environ.copy();env["PATH"]=str(Path(sby).parent)+os.pathsep+env["PATH"]
    for config,name,mode,dirname,depth,detail in TASKS:
      out=BUILD/dirname;start=time.monotonic()
      try:
        run=subprocess.run([sby,"-f","-d",str(out),config],cwd=FORMAL,capture_output=True,text=True,env=env,timeout=600)
        status="PASS" if run.returncode==0 else "FAIL"
        output=run.stdout+run.stderr
      except subprocess.TimeoutExpired as error:
        status="FAIL";detail="solver_timeout"
        output=(error.stdout or b"")+(error.stderr or b"")
        if isinstance(output,bytes):output=output.decode(errors="replace")
      runtime=time.monotonic()-start;(BUILD/f"{dirname}.log").write_text(output)
      rows.append({"group":name,"mode":mode,"status":status,"depth":depth,
        "runtime_seconds":f"{runtime:.3f}","detail":detail})
  REPORT.parent.mkdir(exist_ok=True)
  with REPORT.open("w",newline="")as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator="\n");writer.writeheader();writer.writerows(rows)
  passed=sum(row["status"]=="PASS" for row in rows);print(f"RV32M formal groups: {passed} / {len(rows)} PASS")
  return 0 if passed==len(rows) else 1
if __name__=="__main__":raise SystemExit(main())
