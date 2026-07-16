#!/usr/bin/env python3
"""Compile and run small optional collateral benches."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RTL = ROOT / "rtl"
SIM = ROOT / "sim"
BUILD = ROOT / "build" / "optional_benches"
REPORT = ROOT / "reports" / "optional_bench_summary.csv"
AXI_COVERAGE_CSV = ROOT / "reports" / "axi_lite_coverage_summary.csv"
AXI_COVERAGE_MD = ROOT.parent / "docs" / "reference" / "axi_lite_coverage_summary.md"
CODE_COVERAGE_ARTIFACTS = ROOT / "build" / "verilator_regression" / "artifacts"


def display_path(path: Path) -> str:
    try:
        return path.relative_to(ROOT.parent).as_posix()
    except ValueError:
        return str(path)

WARNINGS = [
    "-Wno-fatal",
    "-Wno-DECLFILENAME",
    "-Wno-PINCONNECTEMPTY",
    "-Wno-WIDTHEXPAND",
    "-Wno-UNUSEDSIGNAL",
    "-Wno-UNUSEDPARAM",
]


@dataclass(frozen=True)
class Bench:
    name: str
    top: str
    sources: tuple[Path, ...]
    pass_token: str


BENCHES = {
    "axi_lite": Bench(
        name="axi_lite",
        top="tb_axi_lite_csr_wrapper",
        sources=(
            SIM / "tb_axi_lite_csr_wrapper.sv",
            RTL / "bus" / "axi_lite_csr_bridge.sv",
        ),
        pass_token="AXIL_RESULT|status=PASS",
    ),
    "cdc_rdc": Bench(
        name="cdc_rdc",
        top="tb_cdc_reset",
        sources=(
            SIM / "tb_cdc_reset.sv",
            RTL / "cdc" / "cdc_sync_2ff.sv",
            RTL / "cdc" / "cdc_pulse_sync.sv",
        ),
        pass_token="CDC_RESULT|status=PASS",
    ),
    "credit_mgr_edges": Bench(
        name="credit_mgr_edges",
        top="tb_credit_mgr_edges",
        sources=(
            SIM / "tb_credit_mgr_edges.sv",
            RTL / "d2d_adapter" / "credit_mgr.sv",
        ),
        pass_token="CREDIT_RESULT|status=PASS",
    ),
}

AXI_REQUIRED_COVERAGE = (
    "basic_rw",
    "doorbell",
    "write_simultaneous",
    "write_aw_first",
    "write_w_first",
    "back_to_back",
    "b_backpressure",
    "r_backpressure",
    "write_wait_state",
    "read_wait_state",
    "partial_wstrb_slverr",
    "out_of_range_slverr",
    "unaligned_slverr",
    "read_while_write_pending",
    "reset_pending_write",
    "reset_pending_read",
    "resp_okay",
    "resp_slverr",
)


def parse_axi_coverage(run_text: str) -> tuple[dict[str, bool], int, int]:
    coverage = {name: False for name in AXI_REQUIRED_COVERAGE}
    assertion_count = 0
    assertion_failures = 0
    for line in run_text.splitlines():
        cov_match = re.search(r"AXIL_COV\|name=([^|]+)\|hit=([01])", line)
        if cov_match and cov_match.group(1) in coverage:
            coverage[cov_match.group(1)] = cov_match.group(2) == "1"
        assert_match = re.search(r"AXIL_ASSERTIONS\|count=(\d+)\|failures=(\d+)", line)
        if assert_match:
            assertion_count = int(assert_match.group(1))
            assertion_failures = int(assert_match.group(2))
    return coverage, assertion_count, assertion_failures


def write_axi_coverage_report(run_text: str, status: str, run_log: Path) -> tuple[str, str]:
    coverage, assertion_count, assertion_failures = parse_axi_coverage(run_text)
    AXI_COVERAGE_CSV.parent.mkdir(parents=True, exist_ok=True)
    AXI_COVERAGE_MD.parent.mkdir(parents=True, exist_ok=True)
    with AXI_COVERAGE_CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["coverage_point", "hit", "source", "notes"],
            lineterminator="\n",
        )
        writer.writeheader()
        for name in AXI_REQUIRED_COVERAGE:
            writer.writerow(
                {
                    "coverage_point": name,
                    "hit": "1" if coverage[name] else "0",
                    "source": "tb_axi_lite_csr_wrapper",
                    "notes": "directed AXI-Lite protocol/control-bus scenario",
                }
            )
    hits = sum(1 for hit in coverage.values() if hit)
    lines = [
        "# AXI-Lite Coverage Summary",
        "",
        "This is directed protocol coverage for the optional AXI-Lite CSR bridge. It is separate from chiplet functional closure and is not commercial AXI VIP signoff.",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
        f"| Bench status | {status} |",
        f"| Coverage points hit | {hits} / {len(AXI_REQUIRED_COVERAGE)} |",
        f"| Protocol assertions | {assertion_count} |",
        f"| Assertion failures | {assertion_failures} |",
        "",
        "| Coverage point | Hit |",
        "| --- | ---: |",
    ]
    for name in AXI_REQUIRED_COVERAGE:
        lines.append(f"| `{name}` | {'yes' if coverage[name] else 'no'} |")
    lines.extend(
        [
            "",
            f"- Run log: `{run_log.relative_to(ROOT.parent)}`",
            "",
        ]
    )
    AXI_COVERAGE_MD.write_text("\n".join(lines))
    if hits != len(AXI_REQUIRED_COVERAGE):
        return "FAIL", f"axi_coverage_{hits}_of_{len(AXI_REQUIRED_COVERAGE)}"
    if assertion_failures:
        return "FAIL", f"axi_assertion_failures_{assertion_failures}"
    return status, f"axi_coverage_{hits}_of_{len(AXI_REQUIRED_COVERAGE)}"


def run_bench(verilator: str, bench: Bench, code_coverage: bool = False) -> dict[str, str]:
    build_dir = BUILD / bench.name
    if build_dir.exists():
        shutil.rmtree(build_dir)
    build_dir.mkdir(parents=True, exist_ok=True)
    binary = build_dir / f"V{bench.top}"
    compile_log = build_dir / "compile.log"
    run_log = build_dir / "run.log"
    coverage_path = CODE_COVERAGE_ARTIFACTS / f"codecov_optional_{bench.name}.coverage.dat"
    if code_coverage:
        CODE_COVERAGE_ARTIFACTS.mkdir(parents=True, exist_ok=True)
        if coverage_path.exists():
            coverage_path.unlink()
    if code_coverage:
        main_cpp = build_dir / f"{bench.top}_coverage_main.cpp"
        main_cpp.write_text(
            "\n".join(
                [
                    "#include <cstdlib>",
                    "#include \"verilated.h\"",
                    "#include \"verilated_cov.h\"",
                    f"#include \"V{bench.top}.h\"",
                    "",
                    "int main(int argc, char** argv) {",
                    "    VerilatedContext context;",
                    "    context.commandArgs(argc, argv);",
                    f"    V{bench.top} top(&context);",
                    "    while (!context.gotFinish()) {",
                    "        top.eval();",
                    "        context.timeInc(1);",
                    "    }",
                    "    top.final();",
                    "    const char* cov = std::getenv(\"VERILATOR_COVERAGE_FILENAME\");",
                    "    VerilatedCov::write(cov ? cov : \"coverage.dat\");",
                    "    return 0;",
                    "}",
                    "",
                ]
            )
        )
        cmd = [
            verilator,
            "--cc",
            "--exe",
            "--build",
            "--sv",
            "--timing",
            "-Wall",
            *WARNINGS,
            "--coverage",
            "--coverage-max-width",
            "32",
            "--top-module",
            bench.top,
            *[str(path) for path in bench.sources],
            str(main_cpp),
            "-Mdir",
            str(build_dir),
        ]
    else:
        cmd = [
            verilator,
            "--binary",
            "--sv",
            "--timing",
            "-Wall",
            *WARNINGS,
            "--top-module",
            bench.top,
            *[str(path) for path in bench.sources],
            "-Mdir",
            str(build_dir),
        ]
    start = time.time()
    compile_result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    compile_log.write_text(
        "## compile_cmd\n"
        + " ".join(cmd)
        + "\n\n## stdout\n"
        + compile_result.stdout
        + "\n## stderr\n"
        + compile_result.stderr
    )
    if compile_result.returncode != 0:
        return {
            "bench": bench.name,
            "status": "FAIL",
            "detail": "compile_failed",
            "elapsed_s": f"{time.time() - start:.3f}",
            "compile_log": display_path(compile_log),
            "run_log": "",
            "coverage_dat": display_path(coverage_path) if code_coverage else "",
        }

    run_env = os.environ.copy()
    if code_coverage:
        run_env["VERILATOR_COVERAGE_FILENAME"] = str(coverage_path)
    run_args = [str(binary)]
    run_result = subprocess.run(run_args, cwd=ROOT, env=run_env, capture_output=True, text=True)
    default_cov = ROOT / "coverage.dat"
    if code_coverage and not coverage_path.exists() and default_cov.exists():
        default_cov.replace(coverage_path)
    run_text = "## stdout\n" + run_result.stdout + "\n## stderr\n" + run_result.stderr
    run_log.write_text(run_text)
    passed = run_result.returncode == 0 and bench.pass_token in run_text
    status = "PASS" if passed else "FAIL"
    detail = "completed" if passed else "run_failed"
    if bench.name == "axi_lite":
        status, detail = write_axi_coverage_report(run_text, status, run_log)
        passed = status == "PASS"
    return {
        "bench": bench.name,
        "status": "PASS" if passed else "FAIL",
        "detail": detail,
        "elapsed_s": f"{time.time() - start:.3f}",
        "compile_log": display_path(compile_log),
        "run_log": display_path(run_log),
        "coverage_dat": display_path(coverage_path) if code_coverage else "",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run optional chiplet collateral benches.")
    parser.add_argument("--bench", action="append", choices=sorted(BENCHES), required=True)
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--code-coverage", action="store_true", help="Build optional bench with Verilator line/expression/toggle/user coverage.")
    args = parser.parse_args()

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    rows = [run_bench(args.verilator, BENCHES[name], code_coverage=args.code_coverage) for name in args.bench]
    existing: list[dict[str, str]] = []
    if REPORT.exists():
        with REPORT.open(newline="") as handle:
            existing = [row for row in csv.DictReader(handle) if row.get("bench") not in set(args.bench)]
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["bench", "status", "detail", "elapsed_s", "compile_log", "run_log", "coverage_dat"],
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows([*existing, *rows])

    for row in rows:
        print(f"{row['bench']}: {row['status']} ({row['detail']})")
    return 1 if any(row["status"] != "PASS" for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
