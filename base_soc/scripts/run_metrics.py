#!/usr/bin/env python3
"""Run RTL and cocotb regressions and print coverage/metric summaries."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, Tuple

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
DEFAULT_ENV = os.environ.copy()


def extend_path_for_venv(env: Dict[str, str]) -> None:
    """Prepend .venv/bin to PATH if it exists so cocotb tooling is found."""
    venv_bin = ROOT / ".venv" / "bin"
    if venv_bin.exists():
        env["PATH"] = f"{venv_bin}:{env.get('PATH', '')}"
        env.setdefault("PYTHONPATH", str(ROOT))
    else:
        print("[metrics] Warning: .venv not found; expecting cocotb in default PATH", file=sys.stderr)


def run_cmd(cmd: Tuple[str, ...], env: Dict[str, str]) -> None:
    print(f"[metrics] Running: {' '.join(cmd)}", flush=True)
    subprocess.run(cmd, cwd=ROOT, env=env, check=True)


def compute_lcov_totals(info: Path) -> Dict[str, float]:
    totals = {
        "lines_hit": 0,
        "lines_total": 0,
        "branches_hit": 0,
        "branches_total": 0,
        "toggles_hit": 0,
        "toggles_total": 0,
    }
    if not info.exists():
        return totals

    for raw in info.read_text(encoding="utf-8", errors="ignore").splitlines():
        if raw.startswith("LH:"):
            totals["lines_hit"] += int(raw[3:])
        elif raw.startswith("LF:"):
            totals["lines_total"] += int(raw[3:])
        elif raw.startswith("BRH:"):
            totals["branches_hit"] += int(raw[4:])
        elif raw.startswith("BRF:"):
            totals["branches_total"] += int(raw[4:])
        elif raw.startswith("TH:"):
            totals["toggles_hit"] += int(raw[3:])
        elif raw.startswith("TF:"):
            totals["toggles_total"] += int(raw[3:])
    return totals


def summarize_metrics() -> None:
    coverage_info = REPORTS / "coverage" / "coverage.info"
    func_cov_yaml = REPORTS / "functional" / "power_cov.yaml"
    regression_json = REPORTS / "regression" / "metrics.json"
    sim_summary = REPORTS / "sim_summary.txt"

    totals = compute_lcov_totals(coverage_info)

    def pct(hit: int, total: int) -> float:
        return 0.0 if total == 0 else (100.0 * hit / total)

    print("[metrics] === Summary ===")
    if coverage_info.exists():
        print(
            "[metrics] Code coverage: statements {:.2f}% ({} / {}), branches {:.2f}% ({} / {}), toggles {:.2f}% ({} / {})".format(
                pct(totals["lines_hit"], totals["lines_total"]),
                totals["lines_hit"],
                totals["lines_total"],
                pct(totals["branches_hit"], totals["branches_total"]),
                totals["branches_hit"],
                totals["branches_total"],
                pct(totals["toggles_hit"], totals["toggles_total"]),
                totals["toggles_hit"],
                totals["toggles_total"],
            )
        )
    else:
        print(f"[metrics] Code coverage report missing: {coverage_info}")

    if func_cov_yaml.exists():
        print(f"[metrics] Functional coverage YAML: {func_cov_yaml}")
    else:
        print("[metrics] Functional coverage YAML not found")

    if regression_json.exists():
        data = json.loads(regression_json.read_text(encoding="utf-8"))
        print(f"[metrics] Regression tests logged: {len(data.get('tests', []))}")
        failures = {
            name: entry["failures"]
            for name, entry in data.get("assertions", {}).items()
            if entry.get("failures", 0)
        }
        if failures:
            print("[metrics] Assertion failures detected:")
            for name, count in failures.items():
                print(f"  - {name}: {count}")
        else:
            print("[metrics] Assertions: all passing")
    else:
        print("[metrics] Regression metrics JSON not found")

    if sim_summary.exists():
        print(f"[metrics] RTL regression summary: {sim_summary}")
    else:
        print("[metrics] RTL regression summary missing")


def main() -> int:
    ap = argparse.ArgumentParser(description="Run verification regressions and collate metrics")
    ap.add_argument("--skip-sim", action="store_true", help="Skip RTL testbench make sim step")
    ap.add_argument("--skip-cocotb", action="store_true", help="Skip cocotb regression")
    ap.add_argument("--jobs", type=int, help="Override parallel job count passed to make")
    args = ap.parse_args()

    env = DEFAULT_ENV.copy()
    extend_path_for_venv(env)

    REPORTS.mkdir(parents=True, exist_ok=True)

    make = shutil.which("make")
    if make is None:
        print("[metrics] Error: make not found", file=sys.stderr)
        return 1

    env_cmd = (make, "env")
    run_cmd(env_cmd, env)

    if not args.skip_sim:
        cmd = [make, "sim"]
        if args.jobs:
            cmd.append(f"J={args.jobs}")
            cmd.append(f"VERILATE_JOBS={args.jobs}")
        run_cmd(tuple(cmd), env)

    if not args.skip_cocotb:
        cmd = [make, "sim_cocotb"]
        if args.jobs:
            cmd.append(f"J={args.jobs}")
        run_cmd(tuple(cmd), env)

    summarize_metrics()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        print(f"[metrics] Command failed with return code {exc.returncode}", file=sys.stderr)
        raise
