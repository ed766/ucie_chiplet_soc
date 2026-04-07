# Verification Plan — UCIe Chiplet Coverage-Driven DV

## Goal

Verify the dual-die RISC-V SoC and behavioral UCIe-style link in
`chiplet_extension/` using a lightweight, coverage-driven environment. The
methodology intentionally avoids full UVM and instead builds on:

- named tests
- lightweight config objects
- passive monitors
- scoreboards and assertions
- functional coverage counters
- automated Verilator regressions

## Testbench Strategy

### Link-focused bench

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - focuses on packetizer, credit flow, retry logic, PHY/channel effects, and
    FLIT-level checking

### End-to-end bench

- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - focuses on the Die A -> Die B -> Die A datapath, ciphertext correctness,
    and negative scenarios

## Stimulus Strategy

### Directed tests

Directed tests target specific behaviors:

- bring-up and nominal datapath
- credit starvation
- receive backpressure
- mid-flight reset
- wrong-key negative case
- misalignment negative case
- bug-validation mode

### Randomized tests

Randomized tests use named scenarios plus seed sweeps:

- `prbs_rand_stress`
- `soc_rand_mix`

The regression runner sweeps multiple seeds automatically so randomized evidence
is part of the default flow rather than a manual extra step.

## Checking Strategy

### Assertions

- `credit_checker.sv`
  - credit accounting and bug-mode detection
- `retry_checker.sv`
  - retry / resend checks
- `ucie_link_checker.sv`
  - bounded training and progress checks

### Scoreboards and monitors

- `ucie_txn_monitor.sv`
  - passive FLIT capture
- `ucie_scoreboard.sv`
  - FLIT ordering, mismatch, drop, and latency tracking
- end-to-end SoC checking
  - compares ciphertext behavior against an independent reference path and
    verifies negative scenarios are actually caught

### Result-line contract

Passing tests emit a standardized `DV_RESULT|...` line with:

- bench
- test
- scenario
- seed
- bug mode
- pass/fail status
- key counters
- coverage totals
- artifact paths

Aborting assertion failures are still regression-visible because the parser
falls back to log signatures and return codes when a `DV_RESULT` line is
missing.

## Coverage Plan

Coverage is monitor-driven and CSV-based so it works cleanly with Verilator.

Tracked functional categories:

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
  - high
- backpressure
  - direct backpressure
  - retry under backpressure
- retry / fault hooks
  - CRC error
  - resend request
  - lane fault
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

## Named Test Plan

### Stable suite

- `prbs_smoke`
- `prbs_credit_starve`
- `prbs_reset_midflight`
- `prbs_backpressure_wave`
- `prbs_rand_stress`
- `soc_smoke`
- `soc_wrong_key`
- `soc_misalign`
- `soc_backpressure`
- `soc_fault_echo`
- `soc_rand_mix`
- `bug_credit_off_by_one`

### Exploratory stress suite

- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`

The stable suite is the default regression gate. The stress suite exists to
exercise retry-heavy behavior and currently serves as an exploratory closure
target rather than a clean pass requirement.

## Bug-Validation Plan

Required injected bug:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`

Expected behavior:

- nominal tests pass without the define
- `bug_credit_off_by_one` fails with the define
- the failure is bucketed as a credit / flow-control problem

## Regression Plan

Primary automation entry point:

- `chiplet_extension/scripts/run_regression.py`

Post-processing:

- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`

Default outputs:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/top_failures.md`
- `chiplet_extension/reports/verification_dashboard.md`

## Acceptance Status

Implemented and verified:

- at least 10 named tests
- directed and randomized tests without bench edits
- multiple-seed automated regression
- automatic coverage sampling and aggregation
- machine-readable result lines
- bug-injection validation for `UCIE_BUG_CREDIT_OFF_BY_ONE`
- README and docs updated for the coverage-driven flow

Still open:

- stable-suite coverage for retry / CRC / lane-fault bins
- closure of the exploratory stress suite without `link_progress` failures
