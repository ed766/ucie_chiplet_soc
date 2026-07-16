# Verification Plan - UCIe Chiplet Coverage-Driven DV

## Goal

Verify the dual-die RISC-V SoC and behavioral UCIe-style link in
`chiplet_extension/` with two verification lanes: the existing lightweight,
coverage-driven Verilator gate, and an optional parallel full-UVM lane for
architecture demonstration. The current default milestone remains centered on
closure, not replacing the stable gate:

- named tests
- lightweight config objects and plusargs
- passive monitors
- scoreboards and assertions
- functional coverage counters
- automated Verilator regressions and dashboards
- UVM-style proxy low-power verification through named Verilator power tests,
  passive monitor sampling, coverage counters, and optional native covergroups
- static UPF intent validation through `make -C chiplet_extension upf-check`
- optional full-UVM lane through `make -C chiplet_extension uvm-check-env`,
  `uvm-smoke`, `uvm-closure`, and `uvm-regress`
- UVM/non-UVM closure equivalence through
  `make -C chiplet_extension closure-equivalence`
- tool-neutral UPF 4.0 intent documentation, not commercial low-power signoff
- bounded Verilator property collateral
- CSR-programmable DMA offload verification with golden-image compare
- firmware-driven RV32/APB MMIO verification through `make -C chiplet_extension firmware-soc-check`

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

### Firmware-driven integration bench

- `chiplet_extension/sim/tb_firmware_soc.sv`
  - executes twelve ROM-backed RV32 programs through `soc_chiplet_rv32_top`
  - drives the existing DMA CSR map through APB MMIO rather than testbench CSR tasks
  - correlates CPU commit, APB transfer, descriptor acceptance, completion, IRQ, and destination-memory evidence
  - checks APB wait/reset/error handling, IRQ masking, queue/full-retire behavior, timeout/parity/invalid-memory errors, CRYPTO_ONLY rejection, and sleep/deep-sleep recovery

### Proxy power benching

- The SoC bench also exercises UPF-aligned power-intent proxy modes.
- These are not UPF-aware simulation runs; they are intentionally modeled
  behaviors that check whether the design reacts correctly to power-state
  intent.

### UPF intent validation

- `chiplet_extension/upf/chiplet_full.upf` captures the chiplet power intent as
  tool-neutral UPF 4.0.
- `chiplet_extension/scripts/check_upf_intent.py` statically validates the UPF
  structure and its RTL hierarchy/control references.
- This validation is a repo-local intent check, not a commercial UPF-aware
  simulation, synthesis, or implementation run.

### Bounded property collateral

- `chiplet_extension/formal/`
  - compact Verilator assertion harnesses for credit, retry, link FSM,
    retry-identity, CRC reject policy, DMA queue/completion, memory integrity,
    and chiplet power-control behavior
- `chiplet_extension/sim/assertions/chiplet_protocol_assertions.svh`
  - reusable assertion intent for DMA queue integrity, credit bounds, retry
    replay, memory integrity, IRQ/pending behavior, and power sequencing
- `docs/reference/assertion_inventory.md`
  - generated assertion inventory grouped by DMA, link/retry/credit,
    memory/parity, and power/retention invariants
- These are bounded property checks, not theorem-proving formal signoff.

### Optional full-UVM bench

- `chiplet_extension/sim/tb_chiplet_uvm.sv`
  - instantiates `soc_chiplet_top`, verification-only virtual interfaces, and
    `run_test()` for the pinned Verilator 5.048/UVM-Verilator lane and other
    full-UVM simulators
  - retains a compatibility runner for older Verilator builds
  - passes CSR, power, UCIe stream, and observation interfaces through
    package-level virtual-interface handles in the Verilator lane
- `chiplet_extension/sim/uvm/`
  - contains full-UVM packages for UCIe, DMA/CSR, power, and the chiplet env
  - keeps UVM agents, sequencers/drivers, passive monitors, analysis ports,
    scoreboards, coverage subscribers, and first-pass UVM smoke tests
  - mirrors key monitor observations into direct counters for the Verilator
    smoke/regression lane
- The pinned `uvm-ci` lane executes phases, TLM analysis paths, scoreboards,
  coverage subscribers, and RAL frontdoor prediction. Full 60-bin UVM closure
  equivalence remains separate from this four-test smoke contract.
- This lane requires external `VERILATOR_UVM` and `UVM_HOME`; the local Debian
  Verilator `5.020` is not treated as sufficient for this optional lane.

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
- static UPF intent structure checks

### Randomized tests

Randomized named scenarios use seed sweeps driven by
`chiplet_extension/scripts/run_regression.py`.

Named scenarios span:

- stable gate
- DMA closure suite
- stress and closure suite
- bug-validation suite
- power-proxy suite
- optional full-UVM smoke and closure suites

Optional seeded-random stress collateral is generated separately from the
stable gate:

- `make -C chiplet_extension random-smoke-25`
- `make -C chiplet_extension stress-retry-50`
- `make -C chiplet_extension power-dma-cross-25`
- `make -C chiplet_extension random-stress-summary`

Those targets create 100 reproducible scenario rows across DMA length,
scratchpad banks, queue pressure, backpressure, CRC/lane faults, parity
injection, timeout profile, retry window, and power-transition timing. They
are optional stress evidence, not default closure requirements.

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
- `dma_golden_model.py`
  - independent Python transaction model for DMA descriptor streams,
    plaintext, packet order, AES ciphertext, and final destination images
- `chiplet_extension/formal/`
  - compact property harnesses for credit bounds, link recovery, retry
    progress, resend identity, CRC reject policy, DMA queue/completion,
    memory integrity, and power-control sidebands

### Scoreboards and monitors

- `ucie_txn_monitor.sv`
  - passive FLIT capture from the actual adapter send path
- `ucie_scoreboard.sv`
  - retry-aware FLIT ordering, mismatch, drop, and latency tracking
- `e2e_ref_scoreboard.sv`
  - file-backed end-to-end reference checking for the SoC bench
- `stats_monitor.sv`
  - monitor-driven functional coverage and CSV output
- `power_state_monitor.sv`
  - passive low-power monitor for PST states, legal transitions, domain
    combinations, isolation effects, retention pulses, and transition/activity
    coverage; it mirrors coverage into CSV counters for Verilator and includes
    simulator-native covergroups/coverpoints when supported

### Full-UVM components

- `ucie_uvm_pkg`
  - UCIe sequence item, sequencer, passive monitor, agent, coverage subscriber,
    and scoreboard
- `dma_uvm_pkg`
  - CSR sequence item, sequencer/driver, DMA event monitor, DMA scoreboard, and
    DMA queue smoke sequence
- `power_uvm_pkg`
  - power-state sequence item, sequencer/driver, passive power monitor,
    coverage subscriber, scoreboard, and sleep/resume sequence
- `chiplet_uvm_pkg`
  - top-level UVM environment and first-pass UVM tests:
    `uvm_prbs_smoke_test`, `uvm_soc_smoke_test`,
    `uvm_dma_queue_smoke_test`, and `uvm_power_sleep_resume_test`

### UPF Intent Validation

`make -C chiplet_extension upf-check` validates:

- UPF version `4.0`
- expected chiplet power domains
- power switches for all switchable domains
- output isolation for all switchable domains
- DMA sleep-context and memory-bank retention strategies
- RUN / CRYPTO_ONLY / SLEEP / DEEP_SLEEP PST values
- referenced RTL hierarchy and `u_pwr_ctrl` sideband controls

This complements, but does not replace, the Verilator power-proxy tests. The
proxy tests verify RTL behavior; `upf-check` verifies static power-intent
structure.

### Low-Power Functional Coverage

The chiplet low-power coverage model stays UVM-style without requiring a full
UVM library: named tests drive scenario intent, the bench connects hierarchical
observability from `u_chiplet.u_pwr_ctrl`, and `power_state_monitor.sv`
passively samples behavior without driving design signals.

The monitor defines native SystemVerilog coverage under non-Verilator
simulators and maintains equivalent counter mirrors for the Verilator report
flow. Relevant coverpoints include:

- PST state: RUN, CRYPTO_ONLY, SLEEP, DEEP_SLEEP
- legal transition: RUN<->CRYPTO_ONLY, RUN<->SLEEP, RUN<->DEEP_SLEEP
- valid PST domain combination: RUN, CRYPTO_ONLY, SLEEP, DEEP_SLEEP
- isolation behavior: asserted, deasserted, blocked traffic, release traffic
- retention event: DMA sleep save/restore and DMA memory save/restore
- activity class: no traffic, link traffic, DMA queued, DMA active,
  completion/IRQ pending
- per-domain switch behavior: on/off observations for each switchable domain
- per-domain isolation behavior: assert/deassert observations for each
  switchable domain
- sequencing behavior: isolation before switch-off, switch-on before restore,
  restore before de-isolation, and retention pulse width

Cross coverage focuses on the meaningful UPF interactions rather than
exhaustive domain permutations:

- power state x valid domain combination
- legal transition x activity class
- isolation behavior x activity class

`power_state_summary.csv` is the closure artifact for this proxy coverage. It
must show all four PST states, all six legal transitions, all four valid
domain-combo bins, all isolation bins, DMA retention save/restore bins, and the
selected transition/activity bins. It also reports per-domain switch,
per-domain isolation, and sequencing coverage. `upf-check` does not contribute
to these functional coverage bins; it only validates static UPF structure.

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
  - legal power-state transitions
  - UPF PST domain combinations
  - isolation assert/deassert and blocked/released traffic behavior
  - DMA sleep-context and memory-retention save/restore events
  - power transition crossed with link/DMA/completion activity
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
- `power_isolation_blocks_tx`
- `power_wakeup_releases_isolation_cleanly`
- `power_transition_with_link_backpressure`
- `power_illegal_access_error_response`
- `power_traffic_cross_test`
- `dma_power_sleep_resume_queue`
- `dma_sleep_during_queued_work`
- `dma_sleep_during_active_transfer`
- `dma_power_state_retention_matrix`
- `dma_crypto_only_submit_blocked`
- `mem_sleep_retained_bank`
- `mem_sleep_nonretained_bank`
- `mem_nonretained_readback_poison_clean`
- `mem_invalid_clear_on_write`
- `mem_deep_sleep_retention_matrix`
- `mem_crypto_only_cfg_access`

### UPF static validation

- `make upf-check`

The stable suite is the default behavioral pass gate. The UPF static validation
lane is required for power-intent documentation consistency. The stress suite
remains checked in and runnable, but it is explicitly treated as closure and
characterization work.

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
  - `memory_integrity`

## Regression Plan

Primary automation:

- `chiplet_extension/scripts/run_regression.py`

Post-processing:

- `chiplet_extension/scripts/parse_regression_results.py`
- `chiplet_extension/scripts/gen_coverage_report.py`
- `chiplet_extension/scripts/gen_failure_summary.py`
- `chiplet_extension/scripts/gen_power_report.py`
- `chiplet_extension/scripts/gen_coverage_closure.py`
- `chiplet_extension/scripts/dma_golden_model.py`
- `chiplet_extension/scripts/run_bounded_properties.py`
- `chiplet_extension/scripts/check_upf_intent.py`
- `chiplet_extension/scripts/check_uvm_env.py`
- `chiplet_extension/scripts/run_uvm_regression.py`
- `chiplet_extension/scripts/check_closure_equivalence.py`
- `chiplet_extension/scripts/gen_code_coverage_report.py`

Required validation commands:

- `make -C chiplet_extension regress`
- `make -C chiplet_extension closure`
- `make -C chiplet_extension closure-equivalence`
- `make -C chiplet_extension power-regress`
- `make -C chiplet_extension upf-check`
- `make -C chiplet_extension firmware-soc-check`
- `make -C chiplet_extension firmware-code-coverage`
- `make -C chiplet_extension coverage-edges-check`
- `make -C chiplet_extension code-coverage`

Optional full-UVM validation commands:

- `make -C chiplet_extension uvm-check-env`
- `make -C chiplet_extension uvm-smoke`
- `make -C chiplet_extension uvm-closure`
- `make -C chiplet_extension uvm-regress`

The UVM commands are intentionally not part of the default pass gate until the
external UVM-capable Verilator environment is installed and the lane has
matching evidence. `uvm-regress` is an alias for the UVM closure lane.

Generated outputs:

- `chiplet_extension/reports/regress_summary.csv`
- `chiplet_extension/reports/coverage_summary.csv`
- `chiplet_extension/reports/failure_buckets.csv`
- `chiplet_extension/reports/top_failures.md`
- `chiplet_extension/reports/code_coverage_summary.md`
- `chiplet_extension/reports/code_coverage_holes.csv`

The code-coverage gate reports raw line/branch/toggle evidence separately from
reviewed toggle coverage. The reviewed denominator excludes only documented
structurally unreachable baseline points and long-horizon diagnostic state;
the six coverage-edge scenarios remain outside canonical functional closure.
- `chiplet_extension/reports/verification_dashboard.md`
- `chiplet_extension/reports/regression_history.csv`
- `chiplet_extension/reports/closure_targets.md`
- `chiplet_extension/reports/power_state_summary.csv`
- `chiplet_extension/reports/coverage_closure_matrix.md`
- `chiplet_extension/reports/closure_equivalence.csv`
- `chiplet_extension/reports/closure_equivalence.md`
- `chiplet_extension/reports/cross_coverage_summary.csv`
- `chiplet_extension/reports/formal_summary.csv`
- `chiplet_extension/reports/perf_characterization.csv`
- `chiplet_extension/reports/firmware_soc_summary.csv`
- `chiplet_extension/reports/firmware_coverage_summary.csv`
- `chiplet_extension/reports/firmware_cross_coverage_summary.csv`
- `chiplet_extension/reports/firmware_code_coverage_summary.md`
- `docs/bug_diary.md`
- `docs/bug_diary.md`
- `docs/reference/debug_case_study_dma_retry.md`
- `docs/images/dma_retry_waveform.png`
- `docs/firmware_soc_verification.md`
- `docs/reference/debug_case_study_firmware_dma.md`
- `docs/images/firmware_dma_waveform.png`
- `docs/performance_characterization.md`

Optional seeded-random collateral:

- `chiplet_extension/reports/random_smoke_25_manifest.csv`
- `chiplet_extension/reports/stress_retry_50_manifest.csv`
- `chiplet_extension/reports/power_dma_cross_25_manifest.csv`
- `chiplet_extension/reports/random_stress_regress_summary.csv`
- `docs/reference/random_stress_summary.md`

Assertion collateral:

- `docs/reference/assertion_inventory.md`

UVM collateral:

- `docs/uvm_status.md`

Optional UVM output:

- `chiplet_extension/reports/uvm_regress_summary.csv`
- `chiplet_extension/reports/uvm_coverage_summary.csv`
- `chiplet_extension/reports/uvm_power_state_summary.csv`
- `chiplet_extension/reports/uvm_smoke_summary.csv`
- `chiplet_extension/reports/uvm_smoke_coverage_summary.csv`
- `chiplet_extension/reports/uvm_*_uvm_coverage.csv`

The UVM coverage files use the same 60-bin coverage metric schema as the
stable Verilator regression coverage files. UVM closure is required to cover
the same required-bin vector as the non-UVM closure lane. `uvm-smoke` remains
fast and writes smoke-prefixed reports so it does not clobber closure evidence.

Evidence split:

- `chiplet_extension/reports/power_state_summary.csv` records behavioral proxy
  power evidence from Verilator runs, including low-power functional coverage
  counter mirrors for states, transitions, domain combinations, isolation,
  retention, and transition/activity crosses.
- `chiplet_extension/reports/uvm_power_state_summary.csv` records the same
  power-proxy closure evidence for the UVM closure lane.
- `chiplet_extension/reports/closure_equivalence.md` records whether UVM and
  non-UVM functional coverage, power coverage, and expected bug-validation
  results are equivalent.
- `make upf-check` console output records static UPF intent evidence.
- `coverage_closure_matrix.md` records both the canonical `60 / 60`
  functional closure vector and non-gating cross-coverage evidence.
- The seeded-random manifests are optional stress inputs; they are not part of
  default closure unless explicitly run through their Make targets.

## Acceptance Status

Current local milestone:

- stable regression currently runs `70 / 70` tests meeting expectation
- nominal stable tests pass at `65 / 65`
- the stable regression and randomized sweeps are Verilator-based
- optional seeded-random stress is supporting evidence and its current status is generated in `docs/project_metrics.md`
- cross-coverage evidence groups are observed at `8 / 8`
- assertion inventory documents `52` protocol/control invariants, including independent APB submission correlation, firmware-to-DMA ordering, and completion-stall stability checks
- firmware-driven integration passes `12 / 12` programs with `30 / 30` required points and `7 / 7` outcome/power crosses
- expected bug-validation failures are observed at `5 / 5`
- low-power proxy rows meet expectation at `26 / 26`
- low-power functional coverage shows PST states `4 / 4`, legal transitions
  `6 / 6`, PST domain combinations `4 / 4`, isolation bins `4 / 4`,
  retention bins `4 / 4`, transition/activity bins `5 / 5`,
  switch-domain bins `12 / 12`, isolation-domain bins `12 / 12`, and
  sequencing bins `4 / 4`
- DMA nominal tests meet expectation at `19 / 19`
- memory nominal tests meet expectation at `15 / 15`
- DMA bug-validation meets expectation at `1 / 1`
- static UPF intent validation passes with `make -C chiplet_extension upf-check`
- bounded Verilator property collateral is checked in and runnable
- machine-readable result lines and CSV/Markdown reports are generated

## Notes for Readers

- `chiplet_extension/` is the flagship verification project.
- `base_soc/` remains as earlier supporting work.
- The chiplet extension includes complete tool-neutral UPF 4.0 intent.
- UPF-aware commercial simulation, synthesis, and implementation signoff remain
  out of scope for this cycle.
- Proxy tests and monitor-driven coverage verify modeled low-power behavior;
  `upf-check` verifies static power-intent structure.
- The next useful extensions are closure trend reporting, low-power proxy
  breadth, and small protocol/performance characterizations.
