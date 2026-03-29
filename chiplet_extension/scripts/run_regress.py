#!/usr/bin/env python3
import argparse
import csv
import os
import random
import subprocess
import time
from pathlib import Path


def collect_rtl_sources(rtl_dir: Path):
    return sorted(str(path) for path in rtl_dir.rglob("*.sv"))


def has_failure(log_text: str) -> bool:
    upper = log_text.upper()
    return "ERROR:" in upper or "FATAL" in upper or "ASSERTION FAILED" in upper


def run_sim(run_id,
            tb_name,
            tb_file,
            rtl_sources,
            sim_dir,
            build_dir,
            log_dir,
            defines,
            plusargs,
            iverilog,
            vvp,
            cwd):
    log_path = log_dir / f"{run_id}_{tb_name}.log"
    vvp_path = build_dir / f"{run_id}_{tb_name}.vvp"

    define_flags = [f"-D{key}={value}" for key, value in sorted(defines.items())]
    compile_cmd = [
        iverilog,
        "-g2012",
        "-Wall",
        f"-I{sim_dir}",
        *define_flags,
        "-o",
        str(vvp_path),
        "-s",
        tb_name,
        str(tb_file),
        *rtl_sources,
    ]

    start_time = time.time()
    compile_result = subprocess.run(
        compile_cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
    )

    log_chunks = []
    log_chunks.append("## compile cmd\n" + " ".join(compile_cmd) + "\n")
    log_chunks.append(compile_result.stdout)
    log_chunks.append(compile_result.stderr)

    if compile_result.returncode != 0:
        log_chunks.append(f"\nCompile failed with code {compile_result.returncode}\n")
        log_path.write_text("".join(log_chunks))
        return {
            "pass": False,
            "log_path": str(log_path),
            "elapsed": time.time() - start_time,
            "returncode": compile_result.returncode,
        }

    run_cmd = [vvp, str(vvp_path)] + [f"+{arg}" for arg in plusargs]
    run_result = subprocess.run(
        run_cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
    )

    log_chunks.append("\n## run cmd\n" + " ".join(run_cmd) + "\n")
    log_chunks.append(run_result.stdout)
    log_chunks.append(run_result.stderr)
    log_path.write_text("".join(log_chunks))

    failed = run_result.returncode != 0 or has_failure(run_result.stdout + run_result.stderr)
    return {
        "pass": not failed,
        "log_path": str(log_path),
        "elapsed": time.time() - start_time,
        "returncode": run_result.returncode,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Run seeded regressions for UCIe chiplet benches.")
    parser.add_argument("--runs", type=int, default=20, help="Number of random PRBS runs.")
    parser.add_argument("--seed", type=int, default=None, help="Seed for regression randomization.")
    parser.add_argument("--out", type=str, default=None, help="CSV summary output path.")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    root_dir = script_dir.parent
    sim_dir = root_dir / "sim"
    rtl_dir = root_dir / "rtl"
    build_dir = root_dir / "build" / "regress"
    log_dir = root_dir / "logs" / "regress"
    reports_dir = root_dir / "reports" / "regress"
    build_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    reports_dir.mkdir(parents=True, exist_ok=True)

    out_path = Path(args.out) if args.out else (root_dir / "reports" / "regress_summary.csv")

    iverilog = os.environ.get("IVERILOG", "iverilog")
    vvp = os.environ.get("VVP", "vvp")

    rtl_sources = collect_rtl_sources(rtl_dir)
    rng = random.Random(args.seed)

    runs = []
    error_nums = [0, 1, 5, 10]
    jitter_vals = [0, 1, 2, 4]
    pipe_vals = [1, 2, 3]
    skew_vals = [1, 2, 3]
    crosstalk_vals = [2, 4, 6]
    reach_vals = [10, 15, 20]

    for idx in range(args.runs):
        seed = rng.getrandbits(32)
        macros = {
            "TB_ERROR_PROB_NUM": rng.choice(error_nums),
            "TB_ERROR_PROB_DEN": 100,
            "TB_JITTER_CYCLES": rng.choice(jitter_vals),
            "TB_PIPELINE_STAGES": rng.choice(pipe_vals),
            "TB_SKEW_STAGES": rng.choice(skew_vals),
            "TB_CROSSTALK_SENSITIVITY": rng.choice(crosstalk_vals),
            "TB_REACH_MM": rng.choice(reach_vals),
        }
        runs.append({
            "id": f"prbs_rand_{idx:03d}",
            "tb": "tb_ucie_prbs",
            "file": sim_dir / "tb_ucie_prbs.sv",
            "seed": seed,
            "macros": macros,
            "plusargs": [f"SEED={seed}"],
            "scenario": "random",
        })

    directed = [
        ("prbs_credit_starve", ["CREDIT_STARVE"]),
        ("prbs_retry_burst", ["RETRY_BURST"]),
        ("prbs_reset_midflight", ["RESET_MIDFLIGHT"]),
    ]
    for name, extra_args in directed:
        seed = rng.getrandbits(32)
        runs.append({
            "id": name,
            "tb": "tb_ucie_prbs",
            "file": sim_dir / "tb_ucie_prbs.sv",
            "seed": seed,
            "macros": {},
            "plusargs": [f"SEED={seed}", *extra_args],
            "scenario": "directed",
        })

    soc_runs = [
        ("soc_baseline", []),
        ("soc_wrong_key", ["NEG_WRONG_KEY"]),
        ("soc_misalign", ["NEG_MISALIGN"]),
    ]
    for name, extra_args in soc_runs:
        runs.append({
            "id": name,
            "tb": "tb_soc_chiplets",
            "file": sim_dir / "tb_soc_chiplets.sv",
            "seed": "",
            "macros": {},
            "plusargs": list(extra_args),
            "scenario": "directed",
        })

    fieldnames = [
        "run_id",
        "test",
        "scenario",
        "seed",
        "error_prob_num",
        "error_prob_den",
        "jitter_cycles",
        "pipeline_stages",
        "skew_stages",
        "crosstalk_sensitivity",
        "reach_mm",
        "plusargs",
        "pass",
        "elapsed_s",
        "log_path",
        "score_path",
        "cov_path",
    ]

    with out_path.open("w", newline="") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for run in runs:
            cov_path = reports_dir / f"{run['id']}_{run['tb']}_coverage.csv"
            score_path = reports_dir / f"{run['id']}_{run['tb']}_scoreboard.csv"
            plusargs = list(run["plusargs"]) + [
                f"COV_OUT={cov_path}",
                f"SCORE_OUT={score_path}",
            ]

            result = run_sim(
                run_id=run["id"],
                tb_name=run["tb"],
                tb_file=run["file"],
                rtl_sources=rtl_sources,
                sim_dir=sim_dir,
                build_dir=build_dir,
                log_dir=log_dir,
                defines=run["macros"],
                plusargs=plusargs,
                iverilog=iverilog,
                vvp=vvp,
                cwd=root_dir,
            )

            macros = run["macros"]
            writer.writerow({
                "run_id": run["id"],
                "test": run["tb"],
                "scenario": run["scenario"],
                "seed": run["seed"],
                "error_prob_num": macros.get("TB_ERROR_PROB_NUM", ""),
                "error_prob_den": macros.get("TB_ERROR_PROB_DEN", ""),
                "jitter_cycles": macros.get("TB_JITTER_CYCLES", ""),
                "pipeline_stages": macros.get("TB_PIPELINE_STAGES", ""),
                "skew_stages": macros.get("TB_SKEW_STAGES", ""),
                "crosstalk_sensitivity": macros.get("TB_CROSSTALK_SENSITIVITY", ""),
                "reach_mm": macros.get("TB_REACH_MM", ""),
                "plusargs": " ".join(plusargs),
                "pass": "PASS" if result["pass"] else "FAIL",
                "elapsed_s": f"{result['elapsed']:.2f}",
                "log_path": result["log_path"],
                "score_path": str(score_path),
                "cov_path": str(cov_path),
            })

    print(f"Regression summary written to {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
