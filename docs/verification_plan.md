# Verification Plan — UCIe Chiplet Coverage-Driven DV

## Goal

Verify the dual-die RISC-V SoC and behavioral UCIe-style link in
`chiplet_extension/` using a lightweight, coverage-driven environment rather
than full UVM. The methodology is built around:

- named tests
- lightweight config objects and plusargs
- passive monitors
- scoreboards and assertions
- functional coverage counters
- automated Verilator regressions and dashboards

## Benches

### Link-focused bench

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - packetizer, credit flow, retry logic, PHY/channel effects, and FLIT-level
    checking

### End-to-end bench

- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - Die A -> Die B -> Die A datapath
  - AES ciphertext checking with a Python-generated reference CSV
  - negative wrong-key and misalignment checks

## Stimulus Strategy

### Directed tests

Directed tests target:

- nominal bring-up
- credit starvation
- retry and lane-fault recovery
- mid-flight reset
- receive backpressure
- wrong-key and misalignment negatives
- explicit bug-validation modes

### Randomized tests

Randomized named scenarios use seed sweeps driven by `run_regression.py`.
Current randomized entries are:

- `prbs_rand_stress`
- `soc_rand_mix`

The stable gate currently uses the lighter randomized PRBS path. The heavier
randomized SoC recovery mix remains in the stress suite until closure improves.

## Checking Strategy

### Assertions

- `credit_checker.sv`
  - credit accounting and flow-control bug detection
- `retry_checker.sv`
  - resend request, replay identity, and replay progress checks
- `ucie_link_checker.sv`
  - bounded training and forward-progress checks

### Scoreboards and monitors

- `ucie_txn_monitor.sv`
  - passive FLIT capture from the actual adapter send path
- `ucie_scoreboard.sv`
  - retry-aware FLIT ordering, mismatch, drop, and latency tracking
- `e2e_ref_scoreboard.sv`
  - file-backed end-to-end reference checking for the SoC bench

### Result-line contract

Passing tests emit a standardized `DV_RESULT|...` line containing:

- bench
- test
- scenario
- seed
- bug mode
- pass/fail status
- key counters
- coverage totals
- artifact paths

Aborting assertion failures remain regression-visible because the parser falls
back to log signatures and process return codes when a `DV_RESULT` line is not
present.

## Coverage Plan

Coverage is monitor-driven and CSV-based so it works cleanly with Verilator.

Tracked categories:

- link FSM visibility
  - reset
  - train
  - active
  - retrain
  - degraded
  - recoveries
- credits
  - zero
  - low
  - mid
  - high
- backpressure
  - direct backpressure
  - retry under backpressure
- retry and fault hooks
  - CRC error
  - resend request
  - lane fault
- latency
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

## Named Test Plan

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

The stable suite is the default pass gate. The stress suite remains part of the
project as explicit closure work.

## Bug-Validation Plan

Required injected bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`
- `UCIE_BUG_CRC_POLY`
- `UCIE_BUG_RETRY_SEQ`

Expected behavior:

- nominal stable tests pass without bug defines
- each bug-validation test fails with its matching define
- failures bucket as:
  - `credit_accounting`
  - `crc_integrity`
  - `retry_identity`

## Regression Plan

Primary automation:

- `chiplet_extension/scripts/run_regression.py`

Post-processing:

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

CI entry points:

- `.github/workflows/smoke_bug.yml`
- `.github/workflows/nightly_regress.yml`

## Acceptance Status

Implemented and verified locally on April 6, 2026:

- 22 named tests exist
- directed and randomized tests run without bench edits
- multiple-seed automated regression is in place
- stable suite currently completes with `16 / 16` runs meeting expectation
- randomized stable runs meet expectation `3 / 3`
- expected bug-validation failures are observed `3 / 3`
- stable functional coverage reaches `18 / 23` bins
- machine-readable result lines and CSV/Markdown reports are generated

Current closure gaps:

- `credit_low`
- `retry_backpressure_cross`
- `latency_low`
- `latency_high`
- `expected_empty`

These are tracked as explicit follow-on items, not hidden failures. The first
three appear in exploratory recovery scenarios that still need stabilization,
`latency_high` needs a deterministic stable-seed trigger, and `expected_empty`
needs a dedicated negative reference-underflow case.
