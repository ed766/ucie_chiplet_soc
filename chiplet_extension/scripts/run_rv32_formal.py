#!/usr/bin/env python3
"""Run standard riscv-formal and project-specific RV32 solver tasks."""

from __future__ import annotations

import argparse
import csv
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
BUILD = ROOT / "build" / "rv32_formal"
REPORT = ROOT / "reports" / "rv32_formal_summary.csv"
EXPECTED_REVISION = "4f29e83a8387a81467716548f165fd97045af617"
CUSTOM_DEPTH = "12"


def row(group: str, mode: str, status: str, depth: str, detail: str) -> dict[str, str]:
    return {"group": group, "mode": mode, "status": status, "depth": depth, "detail": detail}


def run_custom(sby: str | None, mutation: str = "", expect_detection: bool = False) -> dict[str, str]:
    if not sby:
        return row("custom_csr_trap_apb", "bounded_solver", "SKIP", CUSTOM_DEPTH, "sby_missing")
    work = BUILD / "custom"
    shutil.rmtree(work, ignore_errors=True)
    formal_dir = ROOT / "formal" / "rv32"
    source_sby = formal_dir / "rv32_custom.sby"
    generated_sby = formal_dir / ".rv32_custom_mutation.sby"
    sby_file = source_sby
    if mutation:
        generated_sby.write_text(source_sby.read_text()
                                 .replace("depth 12", "depth 10")
                                 .replace("read -formal -D FORMAL -sv",
                                          f"read -formal -D FORMAL -D {mutation} -sv"))
        sby_file = generated_sby
    command = [sby, "-f", str(sby_file)]
    result = subprocess.run(command, cwd=formal_dir, capture_output=True, text=True)
    generated_sby.unlink(missing_ok=True)
    work.parent.mkdir(parents=True, exist_ok=True)
    (BUILD / "custom.log").write_text(result.stdout + result.stderr)
    detected = result.returncode != 0
    passed = detected if expect_detection else not detected
    detail = (f"expected_counterexample:{mutation}" if expect_detection and detected else
              f"mutation_not_detected:{mutation}" if expect_detection else
              "precise_trap_mret_csr_zero_source_mscratch_apb_interrupt_boundary")
    return row("custom_csr_trap_apb", "bounded_solver", "PASS" if passed else "FAIL",
               CUSTOM_DEPTH, detail)


def run_standard(home_text: str, sby: str | None) -> list[dict[str, str]]:
    groups = ("rv32i_instruction_semantics", "register_pc_ordering")
    if not home_text or not Path(home_text).exists() or not sby:
        return [row(group, "riscv-formal", "SKIP", "20-30", "RISCV_FORMAL_HOME_or_sby_missing")
                for group in groups]
    home = Path(home_text)
    revision = subprocess.run(["git", "-C", str(home), "rev-parse", "HEAD"],
                              capture_output=True, text=True).stdout.strip()
    if revision != EXPECTED_REVISION:
        return [row(group, "riscv-formal", "FAIL", "20-30", f"revision_mismatch:{revision}")
                for group in groups]

    workspace = BUILD / "riscv-formal"
    shutil.rmtree(workspace, ignore_errors=True)
    shutil.copytree(home, workspace, symlinks=True)
    core = workspace / "cores" / "ucie_rv32"
    core.mkdir(parents=True)
    for source in ("checks.cfg", "rvfi_wrapper.sv"):
        shutil.copy2(ROOT / "formal" / "rv32" / source, core / source)
    shutil.copy2(ROOT / "sim" / "rvfi" / "rvfi_standard_adapter.sv", core / "rvfi_standard_adapter.sv")
    shutil.copy2(REPO / "base_soc" / "rtl" / "pd1_rv32" / "rv32_core.sv", core / "rv32_core.sv")
    # The pinned riscv-formal revision predates current Yosys' SystemVerilog
    # parser. Preserve its intent while translating the legacy random-variable
    # syntax into the attributes supported by the pinned OSS CAD Suite.
    macros = workspace / "checks" / "rvfi_macros.vh"
    macro_text = macros.read_text()
    macro_text = macro_text.replace("`define rvformal_rand_reg rand reg",
                                    "`define rvformal_rand_reg (* anyseq *) reg")
    macro_text = macro_text.replace("`define rvformal_const_rand_reg const rand reg",
                                    "`define rvformal_const_rand_reg (* anyconst *) reg")
    macros.write_text(macro_text)
    generated = subprocess.run(["python3", "../../checks/genchecks.py"], cwd=core,
                               capture_output=True, text=True)
    (BUILD / "genchecks.log").write_text(generated.stdout + generated.stderr)
    if generated.returncode:
        return [row(group, "riscv-formal", "FAIL", "20-30", "genchecks_failed") for group in groups]
    result = subprocess.run(["make", "-C", "checks", "-j2"], cwd=core, capture_output=True, text=True)
    (BUILD / "checks.log").write_text(result.stdout + result.stderr)
    status = "PASS" if result.returncode == 0 else "FAIL"
    return [row(group, "riscv-formal", status, "20-30", "pinned_riscv_formal_checks")
            for group in groups]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true")
    parser.add_argument("--custom-mutation", default="")
    parser.add_argument("--custom-only", action="store_true")
    parser.add_argument("--expect-detection", action="store_true")
    parser.add_argument("--report", type=Path, default=REPORT)
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    sby = shutil.which("sby")
    rows = [] if args.custom_only else run_standard(os.environ.get("RISCV_FORMAL_HOME", ""), sby)
    rows.append(run_custom(sby, args.custom_mutation, args.expect_detection))
    args.report.parent.mkdir(exist_ok=True)
    with args.report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    passed = sum(item["status"] == "PASS" for item in rows)
    skipped = sum(item["status"] == "SKIP" for item in rows)
    failed = sum(item["status"] == "FAIL" for item in rows)
    print(f"RV32 formal: {passed} PASS, {skipped} SKIP, {failed} FAIL")
    return 1 if failed or (args.require and passed != len(rows)) else 0


if __name__ == "__main__":
    raise SystemExit(main())
