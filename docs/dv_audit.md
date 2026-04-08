# DV Audit — Coverage-Driven UCIe Chiplet Verification

## Scope

This audit captures the current verification state of `chiplet_extension/`.
The upgrade goal was to preserve the lightweight SystemVerilog structure and
turn it into a reproducible coverage-driven DV project, not to replace it with
full UVM.

## What Is Implemented

### Execution benches

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - link-level traffic bench
  - directed and randomized scenario support
- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - full two-die datapath bench
  - file-backed end-to-end checking
  - negative wrong-key and misalignment validation

### Shared DV infrastructure

- `chiplet_extension/sim/dv/txn_pkg.sv`
- `chiplet_extension/sim/dv/stats_pkg.sv`
- `chiplet_extension/sim/dv/stats_monitor.sv`
- `chiplet_extension/sim/dv/ucie_cov_pkg.sv`

### Named test registry

- `chiplet_extension/sim/tests/prbs_tests_pkg.sv`
- `chiplet_extension/sim/tests/soc_tests_pkg.sv`

The project currently exposes 22 named tests split between a stable gate and an
explicit stress/closure suite.

### Checkers and scoreboards

- `chiplet_extension/sim/checkers/credit_checker.sv`
- `chiplet_extension/sim/checkers/retry_checker.sv`
- `chiplet_extension/sim/checkers/ucie_link_checker.sv`
- `chiplet_extension/sim/scoreboard/ucie_txn_monitor.sv`
- `chiplet_extension/sim/scoreboard/ucie_scoreboard.sv`
- `chiplet_extension/sim/scoreboard/e2e_ref_scoreboard.sv`

### Automation and reporting

- `chiplet_extension/scripts/run_regression.py`
- `chiplet_extension/scripts/gen_reference_vectors.py`
- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`

Generated outputs:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/top_failures.md`
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/regression_history.csv`
- `chiplet_extension/reports/closure_targets.md`

## Verified Evidence

The default stable suite was rerun with Verilator on April 6, 2026.

- 16 / 16 runs met expectation
- 13 / 13 nominal runs passed
- 3 / 3 randomized runs met expectation
- 3 / 3 expected bug-validation failures were observed
- 18 / 23 functional coverage bins were hit in the stable suite

Source-of-truth artifacts:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/verification_dashboard.md`

## Bug Validation Status

Validated bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE` -> `credit_accounting`
- `UCIE_BUG_CRC_POLY` -> `crc_integrity`
- `UCIE_BUG_RETRY_SEQ` -> `retry_identity`

All three are exercised by named bug-validation tests and are classified
correctly even when the bench aborts before a `DV_RESULT` line is emitted.

## Improvements Made During The Upgrade

- Named tests removed the need for manual bench edits.
- The SoC bench now uses Python-generated reference vectors via `+REF_CSV`.
- Retry checking and FLIT monitoring now observe the actual adapter send path,
  including replay traffic.
- Machine-readable result lines and CSV coverage made Verilator regressions
  parser-friendly.
- Failure bucketing now distinguishes credit, CRC, and retry-identity failures.
- GitHub Actions workflows were added for smoke/bug checks and nightly
  regression.

## Remaining Gaps

- Stable-suite uncovered bins remain:
  - `credit_low`
  - `retry_backpressure_cross`
  - `latency_low`
  - `latency_high`
  - `expected_empty`
- The stress suite still holds the heavier retry/backpressure and SoC recovery
  scenarios that are useful for closure work but not yet part of the default
  pass gate.
- Power coverage remains proxy-based rather than UPF-aware.

## Audit Conclusion

The project now satisfies the core goals of a lightweight coverage-driven DV
environment:

- named directed and randomized tests
- reusable config objects
- monitor-driven checking and coverage
- machine-readable regression outputs
- automated CSV/Markdown rollups
- multi-bug injection validation

The main next step is closure on the remaining uncovered bins and stress-suite
recovery scenarios, not a change in methodology.

