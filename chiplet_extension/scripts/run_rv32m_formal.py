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

def main()->int:
  candidates=[shutil.which("sby"),str(Path.home()/".cache/oss-cad-suite/bin/sby")]
  sby=next((item for item in candidates if item and Path(item).exists()),None)
  rows=[]
  if not sby:
    rows=[{"group":name,"mode":mode,"status":"SKIP","depth":42,"runtime_seconds":"0.000","detail":"sby_unavailable"}
          for name,mode in (("muldiv_protocol","bounded_safety"),("opcode_reachability","cover"))]
  else:
    shutil.rmtree(BUILD,ignore_errors=True);BUILD.mkdir(parents=True)
    env=os.environ.copy();env["PATH"]=str(Path(sby).parent)+os.pathsep+env["PATH"]
    for config,name,mode,dirname in (("rv32_muldiv_prove.sby","muldiv_protocol","bounded_safety","prove"),("rv32_muldiv_cover.sby","opcode_reachability","cover","cover")):
      out=BUILD/dirname;start=time.monotonic()
      run=subprocess.run([sby,"-f","-d",str(out),config],cwd=FORMAL,capture_output=True,text=True,env=env,timeout=300)
      runtime=time.monotonic()-start;(BUILD/f"{mode}.log").write_text(run.stdout+run.stderr)
      rows.append({"group":name,"mode":mode,"status":"PASS" if run.returncode==0 else "FAIL","depth":42,
        "runtime_seconds":f"{runtime:.3f}","detail":"solver_backed_bmc_z3" if mode=="bounded_safety" else "solver_backed_cover_z3"})
  REPORT.parent.mkdir(exist_ok=True)
  with REPORT.open("w",newline="")as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator="\n");writer.writeheader();writer.writerows(rows)
  passed=sum(row["status"]=="PASS" for row in rows);print(f"RV32M formal groups: {passed} / {len(rows)} PASS")
  return 0 if passed==len(rows) else 1
if __name__=="__main__":raise SystemExit(main())
