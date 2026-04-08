# UCIe Chiplet Extension for the Power-Aware RISC-V SoC

`chiplet_extension/` is the flagship part of this repository. It turns the
original single-die RISC-V SoC into a dual-die system linked by a behavioral
UCIe-style fabric, then verifies that link with a lightweight coverage-driven
SystemVerilog flow built around Verilator, named tests, passive monitors,
scoreboards, assertions, bug injection, and Python-generated dashboards.

## Regression Snapshot

Current checked-in stable-suite evidence, regenerated locally on April 6, 2026:

- Stable runs meeting expectation: `16 / 16`
- Nominal pass rate: `13 / 13`
- Randomized runs meeting expectation: `3 / 3`
- Expected bug-validation failures: `3 / 3`
- Stable functional coverage: `18 / 23` bins (`78.3%`)

Current stable reports:

- `reports/regress_summary.csv`
- `reports/coverage_summary.csv`
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`
- `reports/regression_history.csv`
- `reports/closure_targets.md`

## Layout

- `rtl/`
  - Dual-die RTL, packetizer/depacketizer, credit manager, retry logic, UCIe
    Tx/Rx, PHY/channel models, and `soc_chiplet_top.sv`
- `sim/`
  - `tb_ucie_prbs.sv` for link-level traffic
  - `tb_soc_chiplets.sv` for the Die A -> Die B -> Die A datapath
  - `dv/` for shared config, coverage, stats, and result-line infrastructure
  - `tests/` for named directed and randomized scenarios
  - `checkers/` and `scoreboard/` for assertions, passive monitors, and checking
- `scripts/`
  - Verilator regression runner plus CSV/Markdown post-processing tools
- `reports/`
  - Checked-in regression summary, coverage summary, failure buckets, dashboard,
    trend history, and per-run artifacts
- `openlane/`
  - LibreLane/OpenLane2 configuration for `soc_chiplet_top`
- `upf/`
  - Dual-die UPF scaffolding for always-on vs. switchable domains

## Verification Methodology

The environment stays intentionally lightweight. It does not try to be full
UVM. Instead, it upgrades the original benches into a coverage-driven DV
project with:

- named tests instead of bench edits
- lightweight config objects plus plusargs
- passive monitors and reusable scoreboards
- machine-readable `DV_RESULT|...` lines
- monitor-driven functional coverage counters
- automated Verilator regressions and report generation

Key verification components:

- `sim/dv/txn_pkg.sv`
  - lightweight config objects and runtime knob handling
- `sim/dv/stats_pkg.sv`
  - standardized result-line formatting
- `sim/dv/stats_monitor.sv`
  - monitor-driven functional coverage counters and CSV output
- `sim/dv/ucie_cov_pkg.sv`
  - shared coverage-bin accounting
- `sim/checkers/credit_checker.sv`
  - credit-accounting assertions and bug-mode detection
- `sim/checkers/retry_checker.sv`
  - replay / resend checks wired to the actual adapter send path
- `sim/checkers/ucie_link_checker.sv`
  - bounded training and forward-progress checks
- `sim/scoreboard/ucie_txn_monitor.sv`
  - passive FLIT monitor
- `sim/scoreboard/ucie_scoreboard.sv`
  - retry-aware FLIT scoreboard with latency tracking
- `sim/scoreboard/e2e_ref_scoreboard.sv`
  - file-backed end-to-end checker for the SoC bench
- `scripts/gen_reference_vectors.py`
  - Python golden-model vector generation for `tb_soc_chiplets.sv`

## Named Tests

The project currently exposes 22 named tests.

### Stable suite

- `prbs_smoke`
- `prbs_credit_starve`
- `prbs_retry_single`
- `prbs_lane_fault_recover`
- `prbs_reset_midflight`
- `prbs_backpressure_wave`
- `prbs_rand_stress`
- `soc_smoke`
- `soc_wrong_key`
- `soc_misalign`
- `soc_backpressure`
- `bug_credit_off_by_one`
- `bug_crc_poly`
- `bug_retry_seq`

### Stress and closure suite

- `prbs_retry_backpressure`
- `prbs_crc_burst_recover`
- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `soc_fault_echo`
- `soc_retry_e2e`
- `soc_rand_mix`

The stable suite is the default pass gate. The stress suite remains checked in
and runnable, but it is explicitly treated as closure work rather than hidden.

## Running the DV Flow

From `chiplet_extension/`:

```bash
# Quick smoke run for both benches
make chiplet-sim

# Default stable regression
make regress

# Exploratory retry/fault closure suite
make stress

# Bug-validation-only sweep
make bug-validate
```

Equivalent direct script usage:

```bash
python3 scripts/run_regression.py
python3 scripts/run_regression.py --suite stress
python3 scripts/run_regression.py --suite bug
python3 scripts/run_regression.py --tests prbs_rand_stress --random-seeds 5
```

The SoC bench requires a Python-generated reference file and the regression
runner handles that automatically by passing `+REF_CSV=<path>` to
`tb_soc_chiplets.sv`.

## Result Format and Reports

Passing runs emit a standardized machine-readable line such as:

```text
DV_RESULT|bench=tb_ucie_prbs|test=prbs_smoke|scenario=directed|seed=...|status=PASS|...
```

The report flow is:

1. `scripts/run_regression.py`
2. `scripts/parse_regression_results.py`
3. `scripts/gen_coverage_report.py`
4. `scripts/gen_failure_summary.py`

Generated outputs:

- `reports/regress_summary.csv`
- `reports/coverage_summary.csv`
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`
- `reports/regression_history.csv`
- `reports/closure_targets.md`

Per-run artifacts also land in `reports/` as `*_coverage.csv` and
`*_scoreboard.csv`.

## Coverage Intent

Coverage is CSV-based and Verilator-friendly by design. The shared
`stats_monitor.sv` tracks:

- link FSM visibility
  - reset
  - train
  - active
  - retrain
  - degraded
  - recoveries
- credit regions
  - zero
  - low
  - mid
  - high
- retry / fault hooks
  - CRC error
  - resend request
  - lane fault
- backpressure behavior
  - direct backpressure
  - retry under backpressure
- latency buckets
  - low
  - nominal
  - high
- end-to-end behavior
  - updates
  - mismatches
  - expected-empty underflow
- power visibility proxies
  - reset proxy
  - idle proxy

The current stable suite covers `18 / 23` bins. The remaining uncovered bins in
the checked-in stable dashboard are:

- `credit_low`
- `retry_backpressure_cross`
- `latency_low`
- `latency_high`
- `expected_empty`

Those gaps are now understood well enough to be intentional follow-on closure
work rather than unknown blind spots: some appear in stress-only recovery
scenarios that still need stabilization, while `expected_empty` needs a
dedicated negative reference-underflow test.

## Bug Validation

The repo supports three documented injected bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`
- `UCIE_BUG_CRC_POLY`
- `UCIE_BUG_RETRY_SEQ`

The stable regression demonstrates all three expected failures and buckets them
correctly:

- `bug_credit_off_by_one` -> `credit_accounting`
- `bug_crc_poly` -> `crc_integrity`
- `bug_retry_seq` -> `retry_identity`

## CI Workflows

Two GitHub Actions workflows are included:

- `.github/workflows/smoke_bug.yml`
  - runs `make chiplet-sim`
  - runs `make bug-validate`
- `.github/workflows/nightly_regress.yml`
  - runs the stable regression
  - runs a non-gating randomized closure matrix for `prbs_rand_stress` and
    `soc_rand_mix`

These workflows are included for reproducibility and portfolio presentation.
The checked-in metrics above were generated locally in this workspace.

## Known Gaps

- The stress suite is preserved on purpose and still serves as the active
  closure bucket for heavier retry/backpressure and SoC fault-recovery mixes.
- Power-state coverage is proxy-based (`reset` / `idle`) rather than true
  UPF-aware power simulation.
- The UPF files remain scaffolding and are not integrated into UPF-aware DV.

## Physical-Design Hook

`openlane/chiplet/config.json` points LibreLane/OpenLane2 at `soc_chiplet_top`.
Run it from the LibreLane Nix shell:

```bash
/nix/var/nix/profiles/default/bin/nix-shell --pure <librelane-root>/shell.nix
cd <librelane-root>
librelane \
  --pdk-root <sky130-pdk-root> \
  <repo-root>/chiplet_extension/openlane/chiplet/config.json
```

The DV benches and helper packages live under `sim/` and do not enter the
synthesis file list used by LibreLane.

Verified in this workspace on March 30, 2026: the full LibreLane run completed
78 / 78 stages and wrote final outputs under
`openlane/chiplet/runs/codex_asic_full_20260330_004854/final/`. Magic DRC and
LVS passed. Residual antenna, max slew, and max cap warnings remain, so this is
an end-to-end flow proof point rather than a clean manufacturing sign-off.

## Supporting Docs

- `../docs/dv_audit.md`
- `../docs/verification_plan.md`
- `../docs/bug_case_studies.md`
- `../docs/resume_metrics.md`
