#!/usr/bin/env python3
"""Run pinned Spike comparison when installed; otherwise record an honest SKIP."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from build_compiled_firmware import build_one
from run_compiled_firmware import Scenario, compile_sim, run_one

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "firmware_c"
REPORT = ROOT / "reports" / "rv32_external_iss_summary.csv"


@dataclass(frozen=True)
class Program:
    report_name: str
    source_name: str
    scenario_id: int
    testbench_name: str
    optimization: str


# Exercise instruction semantics, compiled ABI behavior, initialized data,
# control flow, and CSR state under the same optimizer spread used by the
# compiler-matrix lane. Spike remains a CPU-only oracle; device behavior is
# intentionally excluded from this list.
PROGRAMS = (
    *(Program(f"operand_corner_matrix_{opt[1:]}", "operand_corner_matrix", 11,
              "gcc_cpu_only", opt) for opt in ("-O0", "-O1", "-O2", "-Os")),
    *(Program(f"c_abi_stack_call_matrix_{opt[1:]}", "c_abi_stack_call_matrix", 27,
              "gcc_cpu_abi", opt) for opt in ("-O0", "-O1", "-O2", "-Os")),
    Program("c_initialized_data_sections_Os", "c_initialized_data_sections", 26,
            "gcc_cpu_data", "-Os"),
    Program("csr_state_matrix_Os", "csr_state_matrix", 12, "gcc_cpu_only", "-Os"),
    Program("rv32_control_flow_boundary_matrix_O0", "rv32_control_flow_boundary_matrix", 29,
            "gcc_control_boundary", "-O0"),
    Program("rv32_control_flow_boundary_matrix_Os", "rv32_control_flow_boundary_matrix", 29,
            "gcc_control_boundary", "-Os"),
)
SPIKE_REVISION = "907862288f7b2af1afe533a4c74a5f33cc851830"
# Spike emits both a disassembly line and a privilege-qualified commit line for
# each instruction when -l and --log-commits are combined. Match only the
# latter so every architectural retirement is counted exactly once.
SPIKE_RE = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)")


def add_reset_trampoline(manifest: Path) -> None:
    """Describe the RTL-only reset jump used by relocated Spike images."""
    with manifest.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    if rows and rows[0]["pc"] == "00000000":
        return
    with manifest.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("pc", "insn"), lineterminator="\n")
        writer.writeheader()
        writer.writerow({"pc": "00000000", "insn": "0000106f"})
        writer.writerows(rows)


def rtl_sequence(path: Path, minimum_pc: int = 0) -> list[tuple[int, int]]:
    if not path.exists(): return []
    with path.open(newline="") as handle:
        return [(int(row["pc_rdata"], 16), int(row["insn"], 16)) for row in csv.DictReader(handle)
                if row["intr"] == "0" and int(row["insn"], 16) != 0x00100073
                and int(row["pc_rdata"], 16) >= minimum_pc]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true")
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--program", choices=[item.report_name for item in PROGRAMS])
    parser.add_argument("--mutation")
    parser.add_argument("--report", type=Path, default=REPORT)
    parser.add_argument("--expect-detection", action="store_true")
    args = parser.parse_args()
    selected_programs = tuple(item for item in PROGRAMS if not args.program or item.report_name == args.program)
    spike = shutil.which("spike")
    spike_home = Path(os.environ.get("SPIKE_HOME", "")) if os.environ.get("SPIKE_HOME") else None
    revision = (subprocess.run(["git", "-C", str(spike_home), "rev-parse", "HEAD"],
                               capture_output=True, text=True).stdout.strip()
                if spike_home and spike_home.exists() else "")
    if revision != SPIKE_REVISION:
        spike = None
    rows = []
    if not spike:
        for program in selected_programs:
            rows.append({"program": program.report_name, "source": program.source_name,
                         "optimizer": program.optimization, "mutation": args.mutation or "nominal",
                         "detected": 0, "status": "SKIP", "rtl_status": "SKIP",
                         "rtl_retires": 0, "spike_retires": 0,
                         "matched_retires": 0, "rtl_suffix_retires": 0,
                         "first_mismatch": "pinned_spike_missing"})
    else:
        image_dir = BUILD / "spike" / "images"
        linker = ROOT / "firmware_c" / "link_spike.ld"
        binary = compile_sim(args.verilator, False, assertions=True,
                             mutation_define=args.mutation, variant_tag="spike")
        for program in selected_programs:
            artifacts = build_one(program.report_name, program.scenario_id, image_dir,
                                  optimization=program.optimization, linker_script=linker,
                                  text_base_address=0x1000, data_base_address=0x3000)
            add_reset_trampoline(artifacts["manifest"])
            scenario = Scenario(program.report_name, program.testbench_name)
            rtl_result, _ = run_one(binary, scenario, artifacts["hex"], artifact_suffix="_spike")
            trace = BUILD / "traces" / f"{program.report_name}_spike.csv"
            elf = artifacts["elf"]
            command = [spike, "--isa=rv32i_zicsr", "--priv=m", "--pc=0x1000",
                       "--disable-dtb", "-m0x1000:0xf000", "--instructions=2000",
                       "-l", "--log-commits", str(elf)]
            try:
                result = subprocess.run(command, capture_output=True, text=True, timeout=15)
                spike_text = result.stdout + result.stderr
            except subprocess.TimeoutExpired as exc:
                spike_text = (exc.stdout or "") + (exc.stderr or "")
            (image_dir / f"{program.report_name}.spike.log").write_text(spike_text)
            spike_rows = [(int(pc, 16), int(insn, 16)) for pc, insn in SPIKE_RE.findall(spike_text)]
            rtl_rows = rtl_sequence(trace, 0x1000)
            count = min(len(rtl_rows), len(spike_rows))
            mismatch = next((f"index={index}:rtl={rtl_rows[index]}:spike={spike_rows[index]}"
                             for index in range(count) if rtl_rows[index] != spike_rows[index]), "")
            if not mismatch and (not spike_rows or count < min(20, len(rtl_rows))):
                mismatch = "insufficient_spike_trace"
            if rtl_result["status"] != "PASS" and not mismatch:
                mismatch = f"relocated_rtl_failed:{rtl_result['first_mismatch']}"
            detected = bool(mismatch)
            outcome_pass = detected if args.expect_detection else not detected
            rows.append({"program": program.report_name, "source": program.source_name,
                         "optimizer": program.optimization,
                         "mutation": args.mutation or "nominal", "detected": int(detected),
                         "status": "PASS" if outcome_pass else "FAIL",
                         "rtl_status": rtl_result["status"], "rtl_retires": len(rtl_rows),
                         "spike_retires": len(spike_rows), "matched_retires": count,
                         "rtl_suffix_retires": max(0, len(rtl_rows) - count),
                         "first_mismatch": mismatch})
    args.report.parent.mkdir(exist_ok=True)
    with args.report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0], lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    skipped = sum(row["status"] == "SKIP" for row in rows)
    print(f"Spike differential: {passed} PASS, {skipped} SKIP, {len(rows)-passed-skipped} FAIL")
    return 1 if any(row["status"] == "FAIL" for row in rows) or (args.require and passed != len(rows)) else 0


if __name__ == "__main__":
    raise SystemExit(main())
