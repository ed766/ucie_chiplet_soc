# DV Audit — Coverage-Driven UCIe Chiplet Verification

## Scope

This audit captures the current verification state of `chiplet_extension/`. The
goal of the upgrade was to keep the existing lightweight SystemVerilog
structure and incrementally turn it into a coverage-driven DV project, not to
replace it with full UVM.

## What Is Implemented

### Execution benches

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - link-level PRBS traffic bench
  - directed corner cases plus randomized scenario support
- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - full two-die datapath bench
  - end-to-end negative checks for wrong-key and misalignment scenarios

### Shared DV infrastructure

- `chiplet_extension/sim/dv/txn_pkg.sv`
  - lightweight config objects and runtime knob handling
- `chiplet_extension/sim/dv/stats_pkg.sv`
  - standardized `DV_RESULT|...` result-line formatting
- `chiplet_extension/sim/dv/stats_monitor.sv`
  - monitor-driven functional coverage counters
- `chiplet_extension/sim/dv/ucie_cov_pkg.sv`
  - coverage bin accounting and CSV writing

### Named test registry

- `chiplet_extension/sim/tests/prbs_tests_pkg.sv`
- `chiplet_extension/sim/tests/soc_tests_pkg.sv`

The project currently exposes 15 named tests:

- `prbs_smoke`
- `prbs_credit_starve`
- `prbs_retry_burst`
- `prbs_reset_midflight`
- `prbs_backpressure_wave`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `prbs_rand_stress`
- `soc_smoke`
- `soc_wrong_key`
- `soc_misalign`
- `soc_backpressure`
- `soc_fault_echo`
- `soc_rand_mix`
- `bug_credit_off_by_one`

### Checkers and monitors

- `chiplet_extension/sim/checkers/credit_checker.sv`
- `chiplet_extension/sim/checkers/retry_checker.sv`
- `chiplet_extension/sim/checkers/ucie_link_checker.sv`
- `chiplet_extension/sim/scoreboard/ucie_txn_monitor.sv`
- `chiplet_extension/sim/scoreboard/ucie_scoreboard.sv`

### Automation and reporting

- `chiplet_extension/scripts/run_regression.py`
- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`

Generated outputs:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/top_failures.md`
- `chiplet_extension/reports/verification_dashboard.md`

## Verified Evidence

The default stable suite was rerun with Verilator on March 30, 2026.

- 14 total runs met expectation
- 13 / 13 nominal runs passed
- 4 / 4 randomized runs met expectation
- 1 expected bug-validation failure was observed
- 11 / 23 functional coverage bins were hit in the stable suite

Source-of-truth artifacts:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/verification_dashboard.md`

## Bug Validation Status

Required bug mode:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`

Observed behavior:

- `chiplet_extension/sim/checkers/credit_checker.sv` trips as expected
- `parse_regression_results.py` buckets the failure as `credit_assertion`
- `gen_failure_summary.py` rolls it up into `credit_accounting`

Evidence:

- `chiplet_extension/build/verilator_regression/logs/bug_credit_off_by_one_seed6be68c02.log`
- `chiplet_extension/reports/failure_buckets.csv`

## Improvements Made During The Upgrade

- Named tests moved scenario selection out of bench source edits.
- Machine-readable result lines made regression parsing deterministic.
- Coverage collection moved to a shared monitor-driven path.
- A Verilator-native regression runner replaced the older stub / Icarus-oriented
  flow.
- The runner now fingerprints RTL and simulation sources for compile-cache
  invalidation, preventing stale binaries from being reused after bench edits.

## Remaining Gaps

- Retry / CRC / lane-fault bins remain uncovered in the stable suite.
- The exploratory stress tests (`prbs_retry_burst`, `prbs_crc_storm`,
  `prbs_fault_retrain`) still expose a `link_progress` failure bucket under
  aggressive retry churn and are not used as default pass gates.
- Power coverage is still proxy-based (`reset` / `idle`) rather than true
  UPF-aware power simulation.
- The current coverage summary shows verification intent and automated sampling,
  but it is not closure-complete.

## Audit Conclusion

The project now satisfies the core goals of a lightweight coverage-driven DV
environment:

- named directed and randomized tests
- reusable config objects
- monitor-driven checking and coverage
- machine-readable regression outputs
- automated CSV / Markdown rollups
- demonstrable bug-injection validation

The main next step is coverage closure for retry/fault behavior, not a change in
methodology.
