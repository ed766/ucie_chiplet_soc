# Verification Plan - UCIe Chiplet Coverage-Driven DV

## Goal

Verify the dual-die RISC-V SoC and behavioral UCIe-style link in
`chiplet_extension/` with a lightweight, coverage-driven methodology instead
of full UVM. The current milestone is centered on closure, not framework
replacement:

- named tests
- lightweight config objects and plusargs
- passive monitors
- scoreboards and assertions
- functional coverage counters
- automated Verilator regressions and dashboards
- proxy low-power verification
- bounded Verilator property collateral
- CSR-programmable DMA offload verification with golden-image compare

## Benches

### Link-focused bench

- `chiplet_extension/sim/tb_ucie_prbs.sv`
  - packetizer, credit flow, retry logic, PHY/channel effects, and FLIT-level
    checking

### End-to-end bench

- `chiplet_extension/sim/tb_soc_chiplets.sv`
  - Die A -> Die B -> Die A datapath
  - AES ciphertext checking with a Python-generated reference CSV
  - negative wrong-key, misalignment, and expected-empty checks
  - CSR-programmable queued cross-die DMA offload with source/destination
    scratchpads, submit/completion queues, and IRQ-driven completion checking
  - negative DMA programming, queue-full reject, blocked submission, range,
    odd-length, and timeout checks

### Proxy power benching

- The SoC bench also exercises UPF-aligned power-intent proxy modes.
- These are not UPF-aware simulation runs; they are intentionally modeled
  behaviors that check whether the design reacts correctly to power-state
  intent.

### Bounded property collateral

- `chiplet_extension/formal/`
  - compact Verilator assertion harnesses for credit, retry, link FSM, and
    retry-identity behavior
- These are bounded property checks, not theorem-proving formal signoff.

## Stimulus Strategy

### Directed tests

Directed tests target:

- nominal bring-up
- credit starvation and low-credit behavior
- retry and lane-fault recovery
- mid-flight reset
- receive backpressure
- wrong-key, misalignment, and expected-empty negatives
- explicit bug-validation modes
- power-state proxy scenarios

### Randomized tests

Randomized named scenarios use seed sweeps driven by
`chiplet_extension/scripts/run_regression.py`.

The project now has 49 named tests spanning:

- stable gate
- DMA closure suite
- stress and closure suite
- bug-validation suite
- power-proxy suite

## Checking Strategy

### Assertions

- `credit_checker.sv`
  - credit accounting and bug-mode detection
- `retry_checker.sv`
  - resend request, replay identity, and replay progress checks
- `ucie_link_checker.sv`
  - bounded training and forward-progress checks
- `dma_csr_irq_checker.sv`
  - DMA busy/done/error status consistency, IRQ masking, and W1C behavior
- `dma_mem_ref_scoreboard.sv`
  - destination scratchpad compare against a Python-generated expected image
- `chiplet_extension/formal/`
  - compact property harnesses for credit bounds, link recovery, retry
    progress, and resend identity

### Scoreboards and monitors

- `ucie_txn_monitor.sv`
  - passive FLIT capture from the actual adapter send path
- `ucie_scoreboard.sv`
  - retry-aware FLIT ordering, mismatch, drop, and latency tracking
- `e2e_ref_scoreboard.sv`
  - file-backed end-to-end reference checking for the SoC bench
- `stats_monitor.sv`
  - monitor-driven functional coverage and CSV output

### Result-line contract

Passing tests emit a standardized machine-readable `DV_RESULT|...` line
containing:

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
  - run
  - crypto-only
  - sleep
  - deep-sleep
- DMA controller behavior
  - submit/completion queue occupancy
  - queue wrap and drain behavior
  - scratchpad compare
  - IRQ completion
  - submit-reject and runtime-error behavior
  - timeout and blocked-submission errors

## Named Test Plan

### Stable suite

- `prbs_smoke`
- `prbs_credit_starve`
- `prbs_credit_low`
- `prbs_retry_single`
- `prbs_retry_backpressure`
- `prbs_crc_burst_recover`
- `prbs_lane_fault_recover`
- `prbs_reset_midflight`
- `prbs_backpressure_wave`
- `prbs_latency_low`
- `prbs_latency_nominal`
- `prbs_latency_high`
- `prbs_rand_stress`
- `soc_smoke`
- `soc_wrong_key`
- `soc_misalign`
- `soc_backpressure`
- `soc_expected_empty`
- `power_run_mode`
- `power_crypto_only`
- `power_sleep_entry_exit`
- `power_deep_sleep_recover`
- `dma_queue_smoke`
- `dma_queue_back_to_back`
- `dma_queue_full_reject`
- `dma_completion_fifo_drain`
- `dma_irq_masking`
- `dma_odd_len_reject`
- `dma_range_reject`
- `dma_timeout_error`
- `dma_retry_recover_queue`
- `dma_power_sleep_resume_queue`
- `dma_comp_fifo_full_stall`
- `dma_irq_pending_then_enable`
- `dma_comp_pop_empty`
- `dma_reset_mid_queue`
- `dma_tag_reuse`
- `dma_power_state_retention_matrix`
- `dma_crypto_only_submit_blocked`

### Bug-validation subset

- `bug_credit_off_by_one`
- `bug_crc_poly`
- `bug_retry_seq`

### Stress and closure suite

- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `soc_fault_echo`
- `soc_retry_e2e`
- `soc_rand_mix`

### Power-proxy suite

- `power_run_mode`
- `power_crypto_only`
- `power_sleep_entry_exit`
- `power_deep_sleep_recover`

The stable suite is the default pass gate. The stress suite remains checked in
and runnable, but it is explicitly treated as closure and characterization
work.

## Bug-Validation Plan

Required injected bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`
- `UCIE_BUG_CRC_POLY`
- `UCIE_BUG_RETRY_SEQ`
- `UCIE_BUG_DMA_DONE_EARLY`

Expected behavior:

- nominal stable tests pass without bug defines
- each bug-validation test fails with its matching define
- failures bucket as:
  - `credit_accounting`
  - `crc_integrity`
  - `retry_identity`
  - `dma_completion`

## Regression Plan

Primary automation:

- `chiplet_extension/scripts/run_regression.py`

Post-processing:

- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`
- `chiplet_extension/scripts/gen_power_report.py`
- `chiplet_extension/scripts/gen_coverage_closure.py`
- `chiplet_extension/scripts/run_bounded_properties.py`

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
- `docs/protocol_characterization.md`

## Acceptance Status

Current local milestone:

- 49 named tests are documented and runnable
- stable suite closes at `51 / 51` functional bins
- stable regression currently runs `43 / 43` tests meeting expectation, including `39 / 39` nominal passes
- the stable regression and randomized sweeps are Verilator-based
- expected bug-validation failures are observed for all four injected modes
- power-proxy tests meet expectation at `6 / 6`
- DMA nominal tests meet expectation at `17 / 17`
- DMA bug-validation meets expectation at `1 / 1`
- bounded Verilator property collateral is checked in and runnable
- machine-readable result lines and CSV/Markdown reports are generated

## Notes for Readers

- `chiplet_extension/` is the flagship verification project.
- `base_soc/` remains as earlier supporting work.
- UPF-aware simulation is out of scope for this cycle; power behavior is
  represented with explicit proxy tests instead.
- The next useful extensions are closure trend reporting, low-power proxy
  breadth, and small protocol/performance characterizations.
