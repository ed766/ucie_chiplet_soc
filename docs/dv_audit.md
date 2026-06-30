# DV Audit - Coverage-Driven UCIe Chiplet Verification

## Scope

This audit captures the current verification state of `chiplet_extension/`.
The goal was to preserve the lightweight SystemVerilog structure and turn it
into a reproducible coverage-driven DV project, not to replace it with full
UVM.

## What Is Implemented

### Execution benches

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - link-level traffic bench
  - directed and randomized scenario support
  - retry, credit, fault, and latency closure coverage
- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - full two-die datapath bench
  - file-backed end-to-end checking
  - negative wrong-key, misalignment, and expected-empty validation
  - CSR-programmable cross-die DMA offload with scratchpads, IRQ completion,
    timeout handling, and golden-image compare
  - UPF-aligned power-intent proxy scenarios

### Shared DV infrastructure

- `chiplet_extension/sim/dv/txn_pkg.sv`
- `chiplet_extension/sim/dv/stats_pkg.sv`
- `chiplet_extension/sim/dv/stats_monitor.sv`
- `chiplet_extension/sim/dv/ucie_cov_pkg.sv`

### Named test registry

- `chiplet_extension/sim/tests/prbs_tests_pkg.sv`
- `chiplet_extension/sim/tests/soc_tests_pkg.sv`

The project currently exposes 70 named tests spanning the stable gate, DMA
closure, stress closure, bug validation, and power-proxy verification.

### Checkers and scoreboards

- `chiplet_extension/sim/checkers/credit_checker.sv`
- `chiplet_extension/sim/checkers/retry_checker.sv`
- `chiplet_extension/sim/checkers/ucie_link_checker.sv`
- `chiplet_extension/sim/scoreboard/ucie_txn_monitor.sv`
- `chiplet_extension/sim/scoreboard/ucie_scoreboard.sv`
- `chiplet_extension/sim/scoreboard/e2e_ref_scoreboard.sv`

### Proxy power verification

- `chiplet_extension/sim/dv/power_state_monitor.sv`
- `chiplet_extension/reports/power_state_summary.csv`

The power intent story is intentionally proxy-based. It checks whether the SoC
responds correctly to run, crypto-only, sleep, and deep-sleep intent, but it is
not UPF-aware simulation.

### Bounded property collateral

- `chiplet_extension/formal/`
- `chiplet_extension/sim/assertions/chiplet_protocol_assertions.svh`
- `chiplet_extension/scripts/run_bounded_properties.py`
- `chiplet_extension/reports/formal_summary.csv`
- `docs/assertion_inventory.md`

These are bounded Verilator assertion harnesses. They are useful proof-style
collateral, but they are not theorem-proving formal signoff.

### Automation and reporting

- `chiplet_extension/scripts/run_regression.py`
- `chiplet_extension/scripts/dma_golden_model.py`
- `chiplet_extension/scripts/gen_reference_vectors.py`
- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`
- `chiplet_extension/scripts/gen_power_report.py`
- `chiplet_extension/scripts/gen_coverage_closure.py`
- `chiplet_extension/scripts/gen_assertion_inventory.py`
- `chiplet_extension/scripts/gen_random_stress_summary.py`

Generated outputs:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/top_failures.md`
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/regression_history.csv`
- `chiplet_extension/reports/closure_targets.md`
- `chiplet_extension/reports/power_state_summary.csv`
- `chiplet_extension/reports/coverage_closure_matrix.md`
- `chiplet_extension/reports/formal_summary.csv`
- `chiplet_extension/reports/perf_characterization.csv`
- `chiplet_extension/reports/random_smoke_25_manifest.csv`
- `chiplet_extension/reports/stress_retry_50_manifest.csv`
- `chiplet_extension/reports/power_dma_cross_25_manifest.csv`
- `docs/performance_characterization.md`
- `docs/assertion_inventory.md`
- `docs/random_stress_summary.md`
- `docs/bug_diary.md`
- `docs/bug_validation_cases.md`
- `docs/debug_case_study_dma_retry.md`
- `docs/protocol_characterization.md`

## Verified Evidence

The stable Verilator regression now closes the functional coverage model.

- 70 / 70 stable-report runs met expectation
- 65 / 65 nominal stable-report runs passed
- 60 / 60 functional bins were covered in the stable suite
- 1 / 1 randomized stable runs met expectation
- 100 optional seeded-random stress scenarios are generated across the 25/50/25 families
- optional seeded-random stress is supporting evidence; see `docs/project_metrics.md` for the current executed subset result
- 8 / 8 cross-coverage evidence groups were observed
- 52 protocol/control assertion invariants are inventoried, including twelve APB/MMIO and firmware-to-DMA checks
- 5 / 5 expected bug-validation failures were observed
- 26 / 26 power-proxy rows met expectation
- 19 / 19 DMA nominal runs met expectation
- 15 / 15 memory nominal runs met expectation
- 1 / 1 DMA bug-validation run met expectation

Source-of-truth artifacts:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/power_state_summary.csv`
- `chiplet_extension/reports/formal_summary.csv`
- `chiplet_extension/reports/perf_characterization.csv`

## Bug Validation Status

Validated bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE` -> `credit_accounting`
- `UCIE_BUG_CRC_POLY` -> `crc_integrity`
- `UCIE_BUG_RETRY_SEQ` -> `retry_identity`
- `UCIE_BUG_DMA_DONE_EARLY` -> `dma_completion`
- `UCIE_BUG_MEM_PARITY_SKIP` -> `memory_integrity`

The tests are named and explicit, so the project demonstrates bug-injection
validation instead of only nominal smoke passing.

## Improvements Made During The Upgrade

- Named tests removed the need for manual bench edits.
- The SoC bench now uses Python-generated reference vectors via `+REF_CSV`.
- Retry checking and FLIT monitoring now observe the actual adapter send path,
  including replay traffic.
- Machine-readable result lines and CSV coverage made Verilator regressions
  parser-friendly.
- Failure bucketing distinguishes credit, CRC, and retry-identity failures.
- Proxy power verification is tracked separately from the functional DV gate.
- Bounded Verilator property collateral is included for protocol invariants.
- Assertion inventory documentation groups DMA, link, memory, and power invariants
  with their bounded validation evidence.
- Coverage closure is visible in a coverage-to-test mapping report.
- Optional seeded-random stress manifests provide reproducible seed/knob
  metadata without changing the default stable closure gate.
- Lightweight protocol/performance characterization tables are generated from
  the existing named tests.
- The DMA offload path is verified with staged MMIO submission, queued
  completion handling, scratchpad compare, IRQ completion, reject/error cases,
  power-state interactions, and timeout testing.

## Audit Conclusion

The project now satisfies the core goals of a lightweight coverage-driven DV
environment:

- named directed and randomized tests
- reusable config objects
- monitor-driven checking and coverage
- machine-readable regression outputs
- automated CSV/Markdown rollups
- multi-bug injection validation
- proxy low-power verification
- bounded property collateral

The next meaningful extensions are protocol/performance characterization and
incremental low-power or protocol-depth expansion, not a methodology change.
