#!/usr/bin/env python3
"""Run solver-backed prove, cover, and mutation-sensitivity tasks with SBY."""

from __future__ import annotations

import argparse
import csv
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "formal_solver"
REPORT = ROOT / "reports" / "formal_proof_summary.csv"


@dataclass(frozen=True)
class Proof:
    name: str
    top: str
    sources: tuple[str, ...]
    mutation: str
    multiclock: bool = False


PROOFS = (
    Proof("credit_bound", "formal_credit", ("rtl/d2d_adapter/credit_mgr.sv",), "UCIE_BUG_CREDIT_OFF_BY_ONE"),
    Proof("apb_single_operation", "formal_apb", ("rtl/bus/apb_dma_csr_bridge.sv",), "FORMAL_MUTATE_APB"),
    Proof("retry_identity", "formal_retry", ("rtl/d2d_adapter/ucie_tx.sv",), "UCIE_BUG_RETRY_SEQ"),
    Proof("dma_completion_accounting", "formal_dma_accounting", (), "FORMAL_MUTATE_DMA"),
    Proof("invalid_source_containment", "formal_invalid_source", (), "FORMAL_MUTATE_MEMORY"),
    Proof("power_isolation_legality", "formal_power", ("rtl/power/chiplet_power_ctrl.sv",), "FORMAL_MUTATE_POWER"),
    Proof("async_fifo_safety", "formal_async_fifo", ("rtl/cdc/async_fifo_gray.sv",), "ASYNC_FIFO_BUG_FULL", True),
)


def config(proof: Proof, mode: str) -> str:
    define = f"-D {proof.mutation} " if mode == "mutation" else ""
    expected = "expect fail\n" if mode == "mutation" else ""
    sby_mode = "cover" if mode == "cover" else "prove"
    engine = "abc pdr" if mode == "prove" and not proof.multiclock else "smtbmc boolector"
    multiclock = "multiclock on\n" if proof.multiclock else ""
    sources = " ".join((*[Path(source).name for source in proof.sources], "formal_contracts.sv"))
    files = "\n".join((*proof.sources, "formal/solver/formal_contracts.sv"))
    return f"""[options]
mode {sby_mode}
depth 32
timeout 120
{multiclock}{expected}[engines]
{engine}

[script]
read -formal -sv {define}{sources}
prep -top {proof.top}

[files]
{files}
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sby", default="sby")
    args = parser.parse_args()
    sby = shutil.which(args.sby)
    if not sby:
        print("formal-prove: SKIP (sby not found; install pinned OSS CAD Suite)")
        return 0
    BUILD.mkdir(parents=True, exist_ok=True)
    rows = []
    for proof in PROOFS:
        for mode in ("prove", "cover", "mutation"):
            cfg = BUILD / f"{proof.name}_{mode}.sby"
            cfg.write_text(config(proof, mode))
            work = BUILD / f"{proof.name}_{mode}"
            result = subprocess.run([sby, "-f", "-d", str(work), str(cfg)], cwd=ROOT, capture_output=True, text=True)
            log = BUILD / f"{proof.name}_{mode}.log"
            log.write_text(result.stdout + result.stderr)
            rows.append({
                "proof": proof.name, "task": mode,
                "status": "PASS" if result.returncode == 0 else "FAIL",
                "expected": "counterexample" if mode == "mutation" else "pass",
                "evidence": str(log.relative_to(ROOT.parent)),
            })
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"Solver formal: {passed}/{len(rows)} tasks met expectation")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
