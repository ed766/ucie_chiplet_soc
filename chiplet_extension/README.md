# UCIe Chiplet Extension for the Power-Aware RISC-V SoC

`chiplet_extension/` is the flagship part of this repository. It turns the
original single-die RISC-V SoC into a dual-die system linked by a behavioral
UCIe-style fabric, then verifies that link with a lightweight coverage-driven
SystemVerilog flow built around Verilator, named tests, passive monitors,
scoreboards, assertions, bug injection, power-proxy checks, a CSR-programmable
DMA crypto offload path on Die A, a banked parity-protected local memory
subsystem, and Python-generated dashboards.

## Regression Snapshot

Current checked-in evidence, regenerated locally in this workspace:

- Stable runs meeting expectation: `57 / 57`
- Nominal pass rate: `52 / 52`
- Randomized runs meeting expectation: `1 / 1`
- Expected bug-validation failures: `5 / 5`
- DMA nominal runs meeting expectation: `17 / 17`
- Memory nominal runs meeting expectation: `13 / 13`
- Power-proxy runs meeting expectation: `6 / 6`
- Stable functional coverage: `60 / 60` bins (`100.0%`)

Current checked-in reports:

- `reports/regress_summary.csv`
- `reports/coverage_summary.csv`
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`
- `reports/regression_history.csv`
- `reports/closure_targets.md`
- `reports/power_state_summary.csv`
- `reports/coverage_closure_matrix.md`
- `reports/formal_summary.csv`
- `reports/perf_characterization.csv`
- `../docs/protocol_characterization.md`

## Layout

- `rtl/`
  - Dual-die RTL, packetizer/depacketizer, credit manager, retry logic, UCIe
    Tx/Rx, PHY/channel models, `dma_offload_ctrl.sv`, and `soc_chiplet_top.sv`
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
    trend history, power summaries, and per-run artifacts
- `openlane/`
  - LibreLane/OpenLane2 configuration for `soc_chiplet_top`
- `upf/`
  - Dual-die UPF scaffolding for always-on vs. switchable domains
- `formal/`
  - Bounded assertion harnesses for a compact Verilator appendix

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
- UPF-aligned power-proxy verification for the chiplet power states
- bounded assertion harnesses for a small protocol appendix

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
- `sim/checkers/dma_csr_irq_checker.sv`
  - CSR status, IRQ masking, and W1C behavior checks for the DMA control plane
- `sim/dv/dma_completion_monitor.sv`
  - passive DMA descriptor/IRQ/error event tracking
- `sim/scoreboard/ucie_txn_monitor.sv`
  - passive FLIT monitor
- `sim/scoreboard/ucie_scoreboard.sv`
  - retry-aware FLIT scoreboard with latency tracking
- `sim/scoreboard/e2e_ref_scoreboard.sv`
  - file-backed end-to-end checker for the SoC bench
- `sim/scoreboard/dma_mem_ref_scoreboard.sv`
  - destination scratchpad compare against Python-generated golden images
- `scripts/gen_reference_vectors.py`
  - Python golden-model vector generation for `tb_soc_chiplets.sv`, including DMA destination images
- `scripts/run_bounded_properties.py`
  - Verilator-based bounded property appendix for selected protocol blocks

## Named Tests

The project currently exposes 63 named tests.

### Stable nominal suite

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
- `mem_bank_parallel_service`
- `mem_src_bank_conflict`
- `mem_dst_bank_conflict`
- `mem_read_while_dma`
- `mem_write_while_dma_reject`
- `mem_parity_src_detect`
- `mem_parity_dst_maint_detect`
- `mem_sleep_retained_bank`
- `mem_sleep_nonretained_bank`
- `mem_nonretained_readback_poison_clean`
- `mem_invalid_clear_on_write`
- `mem_deep_sleep_retention_matrix`
- `mem_crypto_only_cfg_access`

### Bug-validation subset

- `bug_credit_off_by_one`
- `bug_crc_poly`
- `bug_retry_seq`
- `dma_bug_done_early`
- `mem_bug_parity_skip`

### Stress suite
- `prbs_retry_burst`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `soc_fault_echo`
- `soc_retry_e2e`
- `soc_rand_mix`

The checked-in `make regress` flow runs the stable nominal, power-proxy, and
bug-validation subsets together as the default pass gate. The stress suite
remains checked in and runnable, but it is explicitly treated as closure work
rather than hidden. The power-proxy subset is also runnable on its own through
`make power-regress`.

## DMA Offload Subsystem

Die A now includes a software-visible queued DMA-style crypto offload
controller that wraps the existing UCIe datapath rather than replacing it.

- Fixed 8-bit CSR map for control, status, source/destination base, length, tag,
  IRQ control/status, and indirect scratchpad access
- `256 x 64-bit` source scratchpad and `256 x 64-bit` destination scratchpad
- Staged MMIO submission with a 4-entry internal submit queue and strict
  in-order execution for accepted descriptors
- 4-entry completion FIFO carrying uniform success, runtime-error, and
  submit-reject records
- Level IRQ signaling from sticky pending bits, explicit reject logging, and
  retire-stall behavior when the completion FIFO is full
- Negative/error handling for odd length, out-of-range programming, queue-full
  submission, blocked submission in `CRYPTO_ONLY`, and completion timeout
- Python-generated golden destination image compare for nominal DMA tests
- Dedicated bug mode `UCIE_BUG_DMA_DONE_EARLY` for early-completion validation

## Banked Local Memory Subsystem

The DMA source and destination memories are now implemented as explicit local
memory wrappers rather than flat scratch arrays.

- Each logical `256 x 64-bit` memory is split into two single-ported banks
  (`128 x 64-bit` each)
- DMA traffic and CSR maintenance accesses may complete in parallel only when
  they target different banks of the same memory
- Same-bank conflicts are serialized with fixed DMA priority
- The maintenance path is globally single-issue and uses explicit `MEM_OP_*`
  CSRs rather than direct scratch side effects
- Even parity is generated on every write and checked on every read
- Maintenance parity faults are surfaced through `MEM_OP_STATUS`,
  `MEM_ERR_STATUS`, and `MEM_ERR_COUNT`
- DMA source parity faults abort the active descriptor with `ERR_MEM_PARITY`
- Non-retained banks wake with deterministic poison data, fresh parity, and
  explicit invalid-bank status until rewritten
- The stable suite now includes bank conflict, parity, invalid-read, clear-on-write,
  and CRYPTO_ONLY / SLEEP / DEEP_SLEEP retention tests

## Running the DV Flow

From `chiplet_extension/`:

```bash
# Quick smoke run for both benches
make chiplet-sim

# Default stable regression (nominal + power-proxy + bug-validation)
make regress

# Power-state proxy regression
make power-regress

# Bounded property appendix
make formal-check

# Exploratory retry/fault closure suite
make stress

# Bug-validation-only sweep
make bug-validate

# Small characterization sweeps
make characterize

# Refresh the main stable reports plus appendix artifacts
make chiplet-report
```

Equivalent direct script usage:

```bash
python3 scripts/run_regression.py
python3 scripts/run_regression.py --suite stress
python3 scripts/run_regression.py --suite bug
python3 scripts/run_regression.py --suite power
python3 scripts/run_regression.py --tests prbs_rand_stress --random-seeds 5
python3 scripts/run_bounded_properties.py
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
4. `scripts/gen_power_report.py`
5. `scripts/gen_failure_summary.py`
6. `scripts/gen_coverage_closure.py`

Generated outputs:

- `reports/regress_summary.csv`
- `reports/coverage_summary.csv`
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`
- `reports/regression_history.csv`
- `reports/closure_targets.md`
- `reports/power_state_summary.csv`
- `reports/coverage_closure_matrix.md`
- `reports/formal_summary.csv`
- `reports/perf_characterization.csv`
- `../docs/protocol_characterization.md`

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
 - DMA queue/controller visibility
  - submit/completion occupancy regions
  - queue wrap and full-to-empty drain behavior
  - accepted submission and submit-reject causes
  - runtime-error versus submit-reject completion types
  - retire-stall and reject-overflow observation
  - completion under retry, after recovery, and after sleep resume

The current stable suite covers `51 / 51` bins. The coverage closure matrix in
`reports/coverage_closure_matrix.md` maps each metric to the named tests that
hit it.

## Bug Validation

The repo supports four documented injected bug modes:

- `UCIE_BUG_CREDIT_OFF_BY_ONE`
- `UCIE_BUG_CRC_POLY`
- `UCIE_BUG_RETRY_SEQ`
- `UCIE_BUG_DMA_DONE_EARLY`

The stable regression demonstrates all four expected failures and buckets them
correctly:

- `bug_credit_off_by_one` -> `credit_accounting`
- `bug_crc_poly` -> `crc_integrity`
- `bug_retry_seq` -> `retry_identity`
- `dma_bug_done_early` -> `dma_completion`

## Power-Proxy Verification

The chiplet power story is verified with UPF-aligned proxy tests rather than
true UPF-aware simulation. The goal is to show the intended sequencing and
traffic suppression around:

- `RUN`
- `CRYPTO_ONLY`
- `SLEEP`
- `DEEP_SLEEP`

The checked-in power-suite reports show all six power-proxy runs meeting
expectation and all modeled state/transition bins visited, including the
queued-DMA sleep/resume and retention-matrix scenarios.

## Bounded Appendix

`formal/` contains compact Verilator assertion harnesses for selected protocol
blocks. This is a bounded appendix, not a full theorem-proving flow. It is
useful for interview discussion because it demonstrates a proof mindset without
changing the project away from lightweight SystemVerilog + Verilator.

## CI Workflows

Two GitHub Actions workflows are included:

- `.github/workflows/smoke_bug.yml`
  - runs `make chiplet-sim`
  - runs `make bug-validate`
- `.github/workflows/nightly_regress.yml`
  - runs the stable regression
  - runs a non-gating randomized closure matrix for `prbs_rand_stress` and
    `soc_rand_mix`
  - can also sweep power-state proxy verification and the bounded appendix

These workflows are included for reproducibility and portfolio presentation.
The checked-in metrics above were generated locally in this workspace.

## Known Gaps

- The stress suite is preserved on purpose and still serves as the active
  closure bucket for heavier retry/backpressure and SoC fault-recovery mixes.
- Power-state coverage is proxy-based rather than true UPF-aware power
  simulation.
- The UPF files remain scaffolding and are not integrated into UPF-aware DV.
- The bounded property appendix is intentionally compact; it is not a full
  formal signoff flow.

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

Verified in this workspace on April 7, 2026: the full LibreLane run completed
end-to-end and wrote final outputs under
`openlane/chiplet/runs/codex_asic_full_20260407/final/`. Magic DRC and LVS
passed. Residual antenna, max slew, and max cap warnings remain, so this is an
end-to-end flow proof point rather than a clean manufacturing sign-off.

## Supporting Docs

- `../docs/dv_audit.md`
- `../docs/verification_plan.md`
- `../docs/bug_case_studies.md`
- `../docs/power_verification_plan.md`
- `../docs/formal_appendix.md`
- `../docs/protocol_characterization.md`
- `../docs/resume_metrics.md`
