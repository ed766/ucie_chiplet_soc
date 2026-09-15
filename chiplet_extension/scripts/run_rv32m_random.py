#!/usr/bin/env python3
"""Run deterministic RV32M arithmetic streams against independent Python results."""

from __future__ import annotations

import csv
import random
import re
import shutil
import subprocess
from collections import Counter
from pathlib import Path

from rv32_iss import rv32m_result

ROOT=Path(__file__).resolve().parent.parent
REPO=ROOT.parent
BUILD=ROOT/"build/rv32m_random"
REPORT=ROOT/"reports/rv32m_random_summary.csv"
COUNT=100
OPS_PER_SEED=32

def main()->int:
    shutil.rmtree(BUILD,ignore_errors=True);(BUILD/"vectors").mkdir(parents=True)
    obj=BUILD/"obj"
    command=["verilator","--binary","--sv","--timing","-Wall","-Wno-fatal",
      str(REPO/"base_soc/rtl/pd1_rv32/rv32_muldiv.sv"),str(ROOT/"sim/tb_rv32m_random.sv"),
      "--top-module","tb_rv32m_random","-Mdir",str(obj)]
    compiled=subprocess.run(command,capture_output=True,text=True)
    (BUILD/"compile.log").write_text(compiled.stdout+compiled.stderr)
    if compiled.returncode:return 1
    rows=[]
    corners=(0,1,0xffffffff,0x80000000,0x7fffffff,2,4,8)
    for index in range(COUNT):
      seed=20260914+index;rng=random.Random(seed);mix=Counter();lines=[]
      for item in range(OPS_PER_SEED):
        op=item%8 if item<8 else rng.randrange(8)
        lhs=corners[rng.randrange(len(corners))] if item<16 else rng.getrandbits(32)
        rhs=corners[rng.randrange(len(corners))] if item<16 else rng.getrandbits(32)
        expected=rv32m_result(op,lhs,rhs);mix[op]+=1
        lines.append(f"{op:01x}{lhs:08x}{rhs:08x}{expected:08x}")
      path=BUILD/"vectors"/f"seed_{seed}.hex";path.write_text("\n".join(lines)+"\n")
      run=subprocess.run([str(obj/"Vtb_rv32m_random"),f"+VECTORS={path}",f"+VECTOR_COUNT={OPS_PER_SEED}"],capture_output=True,text=True)
      match=re.search(r"RV32M_RANDOM_SUMMARY\|status=(\w+)\|vectors=(\d+)\|failures=(\d+)\|max_latency=(\d+)",run.stdout)
      passed=run.returncode==0 and match and match.group(1)=="PASS"
      rows.append({"seed":seed,"status":"PASS" if passed else "FAIL","operations":OPS_PER_SEED,
        "opcode_mix":";".join(f"{op}={mix[op]}" for op in range(8)),"failures":match.group(3) if match else "NA",
        "max_latency":match.group(4) if match else "NA","vector_file":str(path.relative_to(REPO))})
    REPORT.parent.mkdir(exist_ok=True)
    with REPORT.open("w",newline="")as handle:
      writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator="\n");writer.writeheader();writer.writerows(rows)
    passed=sum(row["status"]=="PASS" for row in rows);print(f"RV32M random streams: {passed} / {COUNT} PASS")
    return 0 if passed==COUNT else 1
if __name__=="__main__":raise SystemExit(main())
