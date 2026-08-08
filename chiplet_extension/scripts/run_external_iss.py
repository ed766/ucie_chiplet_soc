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
    Program("csr_state_matrix_Os", "csr_state_matrix", 12, "gcc_cpu_only", "-Os"),
    Program("spike_memory_width_matrix_O2", "spike_memory_width_matrix", 47,
            "gcc_cpu_only", "-O2"),
    Program("spike_control_flow_matrix_O2", "spike_control_flow_matrix", 48,
            "gcc_cpu_only", "-O2"),
    Program("spike_dependency_matrix_O2", "spike_dependency_matrix", 49,
            "gcc_cpu_only", "-O2"),
)
SPIKE_REVISION = "907862288f7b2af1afe533a4c74a5f33cc851830"
# Spike emits both a disassembly line and a privilege-qualified commit line for
# each instruction when -l and --log-commits are combined. Match only the
# latter so every architectural retirement is counted exactly once.
SPIKE_RE = re.compile(
    r"core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)(.*)$"
)
REGISTER_RE = re.compile(r"\bx(\d+)\s+0x([0-9a-fA-F]+)")
MEMORY_RE = re.compile(r"\bmem\s+0x([0-9a-fA-F]+)(?:\s+0x([0-9a-fA-F]+))?")


@dataclass(frozen=True)
class Commit:
    pc: int
    insn: int
    rd: int | None = None
    rd_value: int | None = None
    mem_addr: int | None = None
    mem_value: int | None = None
    mem_mask: int = 0


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


def rtl_sequence(path: Path, minimum_pc: int = 0) -> list[Commit]:
    if not path.exists():
        return []
    commits = []
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            pc = int(row["pc_rdata"], 16)
            insn = int(row["insn"], 16)
            if row["intr"] != "0" or insn == 0x00100073 or pc < minimum_pc:
                continue
            rd = int(row["rd_addr"])
            rmask, wmask = int(row["mem_rmask"], 16), int(row["mem_wmask"], 16)
            mem_value = None
            if wmask:
                width = {0: 1, 1: 2, 2: 4}.get((insn >> 12) & 7, 4)
                mem_value = int(row["mem_wdata"], 16) & ((1 << (8 * width)) - 1)
            commits.append(Commit(
                pc=pc, insn=insn,
                rd=rd or None,
                rd_value=int(row["rd_wdata"], 16) if rd else None,
                mem_addr=int(row["mem_addr"], 16) if rmask or wmask else None,
                mem_value=mem_value,
                mem_mask=rmask or wmask,
            ))
    return commits


def spike_sequence(text: str) -> list[Commit]:
    commits = []
    for line in text.splitlines():
        match = SPIKE_RE.search(line)
        if not match:
            continue
        tail = match.group(3)
        register = REGISTER_RE.search(tail)
        memory = MEMORY_RE.search(tail)
        commits.append(Commit(
            pc=int(match.group(1), 16),
            insn=int(match.group(2), 16),
            rd=int(register.group(1)) if register else None,
            rd_value=int(register.group(2), 16) if register else None,
            mem_addr=int(memory.group(1), 16) if memory else None,
            mem_value=int(memory.group(2), 16) if memory and memory.group(2) else None,
        ))
    return commits


def compare_commit(index: int, rtl: Commit, spike: Commit) -> str:
    prefix = f"index={index}"
    if (rtl.pc, rtl.insn) != (spike.pc, spike.insn):
        return (f"{prefix}:pc_insn:rtl=({rtl.pc:#010x},{rtl.insn:#010x}):"
                f"spike=({spike.pc:#010x},{spike.insn:#010x})")
    if (rtl.rd, rtl.rd_value) != (spike.rd, spike.rd_value):
        return (f"{prefix}:register:rtl=({rtl.rd},{rtl.rd_value}):"
                f"spike=({spike.rd},{spike.rd_value})")
    if rtl.mem_addr != spike.mem_addr:
        return f"{prefix}:memory_address:rtl={rtl.mem_addr}:spike={spike.mem_addr}"
    if spike.mem_value is not None and rtl.mem_value != spike.mem_value:
        return f"{prefix}:store_value:rtl={rtl.mem_value}:spike={spike.mem_value}"
    if rtl.mem_addr is not None:
        opcode = rtl.insn & 0x7f
        funct3 = (rtl.insn >> 12) & 7
        width = ({0: 1, 1: 2, 4: 1, 5: 2}.get(funct3, 4)
                 if opcode == 0x03 else {0: 1, 1: 2, 2: 4}.get(funct3, 0))
        expected_mask = (((1 << width) - 1) << (rtl.mem_addr & 3)) & 0xf if width else 0
        if rtl.mem_mask != expected_mask:
            return f"{prefix}:memory_mask:rtl={rtl.mem_mask:#x}:expected={expected_mask:#x}"
    return ""


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
                         "matched_retires": 0, "matched_register_writes": 0,
                         "matched_memory_accesses": 0, "rtl_suffix_retires": 0,
                         "terminal_relation": "SKIP",
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
            mutation_suffix = f"_{args.mutation.lower()}" if args.mutation else ""
            artifact_suffix = f"_spike{mutation_suffix}"
            rtl_result, _ = run_one(binary, scenario, artifacts["hex"], artifact_suffix=artifact_suffix)
            trace = BUILD / "traces" / f"{program.report_name}{artifact_suffix}.csv"
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
            spike_rows = spike_sequence(spike_text)
            rtl_rows = rtl_sequence(trace, 0x1000)
            count = min(len(rtl_rows), len(spike_rows))
            mismatch = next((detail for index in range(count)
                             if (detail := compare_commit(index, rtl_rows[index], spike_rows[index]))), "")
            if not mismatch and (not spike_rows or count < min(20, len(rtl_rows))):
                mismatch = "insufficient_spike_trace"
            if rtl_result["status"] != "PASS" and not mismatch:
                mismatch = f"relocated_rtl_failed:{rtl_result['first_mismatch']}"
            terminal_relation = "spike_mailbox_fault_rtl_mailbox_accept"
            if not mismatch and not ("trap_store_access_fault" in spike_text and
                                     re.search(r"tval\s+0x0*1e0\b", spike_text)):
                mismatch = "unexpected_spike_termination"
                terminal_relation = "unexpected"
            suffix = max(0, len(rtl_rows) - count)
            if not mismatch and suffix > 4:
                mismatch = f"unexpected_rtl_suffix:{suffix}"
                terminal_relation = "unexpected"
            detected = bool(mismatch)
            outcome_pass = detected if args.expect_detection else not detected
            rows.append({"program": program.report_name, "source": program.source_name,
                         "optimizer": program.optimization,
                         "mutation": args.mutation or "nominal", "detected": int(detected),
                         "status": "PASS" if outcome_pass else "FAIL",
                         "rtl_status": rtl_result["status"], "rtl_retires": len(rtl_rows),
                         "spike_retires": len(spike_rows), "matched_retires": count,
                         "matched_register_writes": sum(spike_rows[index].rd is not None for index in range(count)),
                         "matched_memory_accesses": sum(spike_rows[index].mem_addr is not None for index in range(count)),
                         "rtl_suffix_retires": suffix, "terminal_relation": terminal_relation,
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
