#!/usr/bin/env python3
"""Build and run the firmware-driven RV32/chiplet integration suite."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from assemble_rv32_firmware import assemble


ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
BUILD = ROOT / "build" / "firmware_soc"
REPORTS = ROOT / "reports"
DOC = REPO / "docs" / "firmware_soc_verification.md"


@dataclass(frozen=True)
class Scenario:
    name: str
    source: str
    ref_args: tuple[str, ...] = ()
    trace: bool = False


SCENARIOS = (
    Scenario("dma_smoke", "dma_smoke.S", ("--dma-src-base", "0", "--dma-dst-base", "32", "--dma-len-words", "4", "--dma-tag", "0x101"), True),
    Scenario("dma_back_to_back", "dma_back_to_back.S", ("--dma-src-base", "0", "--dma-dst-base", "32", "--dma-len-words", "4", "--dma-tag", "0x101", "--queue-pressure", "pair", "--dma2-src-base", "4", "--dma2-dst-base", "40", "--dma2-len-words", "4", "--dma2-tag", "0x102")),
    Scenario("crypto_only_reject", "crypto_only_reject.S"),
    Scenario("apb_wait_error", "apb_wait_error.S"),
    Scenario("sleep_resume", "sleep_resume.S", ("--dma-src-base", "0", "--dma-dst-base", "48", "--dma-len-words", "8", "--dma-tag", "0x177")),
    Scenario("irq_pending_then_enable", "irq_pending_then_enable.S", ("--dma-src-base", "0", "--dma-dst-base", "64", "--dma-len-words", "4", "--dma-tag", "0x201")),
    Scenario("queue_full_reject", "queue_full_reject.S"),
    Scenario("completion_fifo_stall", "completion_fifo_stall.S", ("--dma-src-base", "0", "--dma-dst-base", "96", "--dma-len-words", "4", "--dma-tag", "0x401", "--queue-pressure", "five")),
    Scenario("timeout_error", "timeout_error.S"),
    Scenario("parity_source_error", "parity_source_error.S"),
    Scenario("deep_sleep_invalid_source", "deep_sleep_invalid_source.S"),
    Scenario("apb_reset_mid_wait", "apb_reset_mid_wait.S", ("--dma-src-base", "0", "--dma-dst-base", "120", "--dma-len-words", "4", "--dma-tag", "0x181")),
)

SMOKE_TESTS = ("dma_smoke", "apb_wait_error")

REQUIRED_COVERAGE = (
    "apb_read", "apb_write", "apb_zero_wait", "apb_wait_read",
    "apb_wait_write", "apb_range_error", "apb_unaligned_error", "apb_reset_recovery",
    "fw_polling", "fw_doorbell", "fw_completion_read", "fw_completion_pop",
    "fw_irq_masked", "fw_irq_pending_enable", "fw_ordered_tags", "fw_bus_error",
    "dma_success", "dma_two_in_order", "dma_queue_full_reject", "dma_blocked_reject",
    "dma_timeout", "dma_parity_error", "dma_invalid_error",
    "cross_run_success", "cross_run_timeout", "cross_run_parity", "cross_crypto_reject",
    "cross_sleep_resume", "cross_deep_invalid", "cross_wait_no_retire",
)

REQUIRED_CROSSES = tuple(name for name in REQUIRED_COVERAGE if name.startswith("cross_"))


RESULT_RE = re.compile(r"FIRMWARE_RESULT\|(?P<fields>[^\n]+)")


def rtl_sources() -> list[str]:
    sources = [str(REPO / "base_soc" / "rtl" / "pd1_rv32" / "rv32_core.sv")]
    sources.extend(str(path) for path in sorted((ROOT / "rtl").rglob("*.sv")))
    return sources


def compile_binary(verilator: str, code_coverage: bool) -> Path:
    obj_dir = BUILD / ("obj_dir_coverage" if code_coverage else "obj_dir")
    if obj_dir.exists():
        shutil.rmtree(obj_dir)
    obj_dir.mkdir(parents=True)
    common = [
        verilator, "--sv", "--timing", "-Wall",
        "-Wno-fatal",
        "-Wno-DECLFILENAME",
        "-Wno-PINCONNECTEMPTY",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-UNUSEDPARAM",
        "-Wno-BLKSEQ",
        f"-I{ROOT / 'sim'}", *rtl_sources(), str(ROOT / "sim" / "tb_firmware_soc.sv"),
        "--top-module", "tb_firmware_soc", "-Mdir", str(obj_dir),
    ]
    if code_coverage:
        main_cpp = BUILD / "firmware_coverage_main.cpp"
        main_cpp.write_text(
            "\n".join(
                [
                    "#include <cstdlib>",
                    "#include \"verilated.h\"",
                    "#include \"verilated_cov.h\"",
                    "#include \"Vtb_firmware_soc.h\"",
                    "int main(int argc, char** argv) {",
                    "  VerilatedContext context; context.commandArgs(argc, argv);",
                    "  Vtb_firmware_soc top(&context);",
                    "  while (!context.gotFinish()) { top.eval(); context.timeInc(1); }",
                    "  top.final();",
                    "  const char* cov = std::getenv(\"VERILATOR_COVERAGE_FILENAME\");",
                    "  VerilatedCov::write(cov ? cov : \"firmware.coverage.dat\");",
                    "  return 0;",
                    "}",
                ]
            ) + "\n"
        )
        cmd = [*common[:1], "--cc", "--exe", "--build", *common[1:], "--coverage-line", str(main_cpp)]
    else:
        cmd = [*common[:1], "--binary", *common[1:]]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    (BUILD / "compile.log").write_text(" ".join(cmd) + "\n\n" + result.stdout + result.stderr)
    if result.returncode != 0:
        raise RuntimeError(f"firmware SoC compile failed; see {BUILD / 'compile.log'}")
    return obj_dir / "Vtb_firmware_soc"


def generate_reference(scenario: Scenario) -> Path | None:
    if not scenario.ref_args:
        return None
    path = BUILD / "references" / f"{scenario.name}.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        str(ROOT / "scripts" / "gen_reference_vectors.py"),
        "--test",
        scenario.name,
        "--output",
        str(path),
        *scenario.ref_args,
    ]
    subprocess.run(cmd, cwd=ROOT, check=True)
    return path


def parse_result(output: str) -> dict[str, str]:
    match = RESULT_RE.search(output)
    if not match:
        return {}
    result: dict[str, str] = {}
    for item in match.group("fields").split("|"):
        if "=" in item:
            key, value = item.split("=", 1)
            result[key] = value
    return result


def repo_path(path: Path) -> str:
    return str(path.relative_to(REPO))


def report_path(report_prefix: str, kind: str) -> Path:
    if report_prefix == "firmware_soc_":
        names = {
            "summary": "firmware_soc_summary.csv",
            "coverage": "firmware_coverage_summary.csv",
            "cross": "firmware_cross_coverage_summary.csv",
        }
        return REPORTS / names[kind]
    suffixes = {
        "summary": "summary.csv",
        "coverage": "coverage_summary.csv",
        "cross": "cross_coverage_summary.csv",
    }
    return REPORTS / f"{report_prefix}{suffixes[kind]}"


def run_scenario(binary: Path, scenario: Scenario, code_coverage: bool) -> dict[str, str]:
    firmware_dir = BUILD / "firmware"
    firmware_dir.mkdir(parents=True, exist_ok=True)
    hex_path = firmware_dir / f"{scenario.name}.hex"
    assemble(ROOT / "firmware" / scenario.source, hex_path)
    coverage_path = BUILD / "coverage" / f"{scenario.name}.csv"
    coverage_path.parent.mkdir(parents=True, exist_ok=True)
    log_path = BUILD / "logs" / f"{scenario.name}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    ref_path = generate_reference(scenario)
    trace_path = BUILD / "firmware_dma_trace.csv" if scenario.trace else None
    cmd = [
        str(binary),
        f"+TEST={scenario.name}",
        f"+FIRMWARE_HEX={hex_path}",
        f"+COVER_OUT={coverage_path}",
    ]
    if ref_path:
        cmd.append(f"+REF_CSV={ref_path}")
    if trace_path:
        cmd.append(f"+TRACE_OUT={trace_path}")
    env = None
    coverage_dat = ""
    if code_coverage:
        coverage_dat_path = BUILD / "coverage_data" / f"firmware_{scenario.name}.coverage.dat"
        coverage_dat_path.parent.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, VERILATOR_COVERAGE_FILENAME=str(coverage_dat_path))
        coverage_dat = repo_path(coverage_dat_path)
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=180, env=env)
    output = result.stdout + result.stderr
    log_path.write_text(" ".join(cmd) + "\n\n" + output)
    fields = parse_result(output)
    status = "PASS" if result.returncode == 0 and fields.get("status") == "PASS" else "FAIL"
    return {
        "test": scenario.name,
        "status": status,
        "returncode": str(result.returncode),
        "cycles": fields.get("cycles", "NA"),
        "mmio_reads": fields.get("mmio_reads", "NA"),
        "mmio_writes": fields.get("mmio_writes", "NA"),
        "wait_cycles": fields.get("wait", "NA"),
        "bus_errors": fields.get("bus_errors", "NA"),
        "doorbells": fields.get("doorbells", "NA"),
        "accepted": fields.get("accepts", "NA"),
        "completions": fields.get("completions", "NA"),
        "rejects": fields.get("rejects", "NA"),
        "successes": fields.get("success", "NA"),
        "runtime_errors": fields.get("runtime_errors", "NA"),
        "assertion_failures": fields.get("assertion_failures", "NA"),
        "memory_mismatches": fields.get("mem_mismatch", "NA"),
        "firmware_hex": repo_path(hex_path),
        "coverage_csv": repo_path(coverage_path),
        "log": repo_path(log_path),
        "coverage_dat": coverage_dat,
    }


def write_summary(rows: list[dict[str, str]], report_prefix: str) -> Path:
    REPORTS.mkdir(exist_ok=True)
    path = report_path(report_prefix, "summary")
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return path


def write_coverage(rows: list[dict[str, str]], report_prefix: str, require_closure: bool) -> tuple[int, int]:
    observed: dict[str, dict[str, str]] = {}
    for row in rows:
        coverage_path = REPO / row["coverage_csv"]
        if not coverage_path.exists():
            continue
        with coverage_path.open(newline="") as handle:
            for cov in csv.DictReader(handle):
                entry = observed.setdefault(cov["coverage_point"], {"hit": "0", "tests": ""})
                if cov["hit"] == "1":
                    entry["hit"] = "1"
                    entry["tests"] = ",".join(filter(None, (entry["tests"], row["test"])))
    required = list(REQUIRED_COVERAGE if require_closure else sorted(observed))
    path = report_path(report_prefix, "coverage")
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["coverage_point", "hit", "tests"])
        for name in required:
            entry = observed.get(name, {"hit": "0", "tests": ""})
            writer.writerow([name, entry["hit"], entry["tests"]])
    hit = sum(observed.get(name, {}).get("hit") == "1" for name in required)
    return hit, len(required)


def write_cross_coverage(rows: list[dict[str, str]], report_prefix: str) -> tuple[int, int]:
    observed: dict[str, set[str]] = {name: set() for name in REQUIRED_CROSSES}
    for row in rows:
        coverage_path = REPO / row["coverage_csv"]
        if not coverage_path.exists():
            continue
        with coverage_path.open(newline="") as handle:
            for cov in csv.DictReader(handle):
                if cov["coverage_point"] in observed and cov["hit"] == "1":
                    observed[cov["coverage_point"]].add(row["test"])
    path = report_path(report_prefix, "cross")
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["cross", "hit", "tests"])
        for name in REQUIRED_CROSSES:
            writer.writerow([name, int(bool(observed[name])), ",".join(sorted(observed[name]))])
    return sum(bool(tests) for tests in observed.values()), len(REQUIRED_CROSSES)


def write_doc(rows: list[dict[str, str]], coverage: tuple[int, int], crosses: tuple[int, int]) -> None:
    code_coverage_pct = "NA"
    code_report = REPORTS / "firmware_code_coverage_summary.txt"
    if code_report.exists():
        for line in code_report.read_text().splitlines():
            if line.startswith("focus_line_coverage_pct="):
                code_coverage_pct = line.split("=", 1)[1] + "%"
                break
    lines = [
        "# Firmware-Driven RV32 SoC Verification",
        "",
        "The lightweight RV32 core executes ROM-backed assembly and controls the chiplet DMA through APB MMIO. Testbench CSR writes are not used in this lane.",
        "",
        "| Scenario | Status | Cycles | MMIO reads/writes | Wait cycles | Bus errors | DMA accepted/completed |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in rows:
        lines.append(
            f"| `{row['test']}` | `{row['status']}` | {row['cycles']} | {row['mmio_reads']} / {row['mmio_writes']} | {row['wait_cycles']} | {row['bus_errors']} | {row['accepted']} / {row['completions']} |"
        )
    lines.extend(
        [
            "",
            f"Firmware/MMIO coverage: **{coverage[0]} / {coverage[1]}** required points.",
            f"Firmware outcome/power crosses: **{crosses[0]} / {crosses[1]}** required crosses.",
            f"Focused RV32/APB/ROM integration line coverage: **{code_coverage_pct}**.",
            "",
            "## Evidence Boundary",
            "",
            "- The program uses the intentionally small instruction subset supported by `rv32_core`.",
            "- APB accesses stall instruction retirement until `PREADY`; invalid MMIO produces `bus_error`.",
            "- The main chiplet data path remains the behavioral UCIe-style link; AXI-Lite remains optional external CSR collateral.",
            "- This is behavioral open-source simulation evidence, not commercial SoC or power-aware signoff.",
        ]
    )
    DOC.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--tests", default="", help="Comma-separated scenario names.")
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--code-coverage", action="store_true")
    parser.add_argument("--report-prefix", default="firmware_soc_")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    if args.code_coverage:
        shutil.rmtree(BUILD / "coverage_data", ignore_errors=True)
    selected_names = set(SMOKE_TESTS if args.smoke else ())
    if args.tests:
        selected_names = {name.strip() for name in args.tests.split(",") if name.strip()}
    selected = [scenario for scenario in SCENARIOS if not selected_names or scenario.name in selected_names]
    unknown = selected_names - {scenario.name for scenario in SCENARIOS}
    if unknown:
        raise SystemExit(f"Unknown firmware scenarios: {', '.join(sorted(unknown))}")
    binary = compile_binary(args.verilator, args.code_coverage)
    rows = [run_scenario(binary, scenario, args.code_coverage) for scenario in selected]
    summary_path = write_summary(rows, args.report_prefix)
    require_closure = len(selected) == len(SCENARIOS)
    coverage = write_coverage(rows, args.report_prefix, require_closure)
    crosses = write_cross_coverage(rows, args.report_prefix)
    if args.report_prefix == "firmware_soc_":
        write_doc(rows, coverage, crosses)
    failures = [row["test"] for row in rows if row["status"] != "PASS"]
    if require_closure and coverage[0] != coverage[1]:
        failures.append(f"coverage_{coverage[0]}_of_{coverage[1]}")
    if require_closure and crosses[0] != crosses[1]:
        failures.append(f"crosses_{crosses[0]}_of_{crosses[1]}")
    print(f"Firmware SoC summary: {summary_path}")
    print(f"Firmware coverage: {coverage[0]} / {coverage[1]}")
    print(f"Firmware crosses: {crosses[0]} / {crosses[1]}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
