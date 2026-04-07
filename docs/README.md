# UCIe Chiplet SoC: Functional Behavior

This document explains what the project *does at runtime*.
It focuses on system behavior and control/data flow, not just file lists or UPF structure.

## 1) What This Project Actually Computes

The repository has two connected implementations:

- `base_soc/`: a single-die APB SoC with always-on control logic, a timer, a switchable RV32 domain, and a switchable AES register/core domain.
- `chiplet_extension/`: a two-die model where Die A generates plaintext traffic, sends it over a UCIe-style behavioral link, Die B encrypts with AES-128, and returns ciphertext to Die A for checking.

In short, the chiplet system is a looped crypto service:

`plaintext stream (Die A) -> FLIT/link transport -> AES encrypt (Die B) -> return link -> scoreboard check (Die A)`

## 2) Base SoC Runtime Logic (`base_soc/`)

### APB and Block Routing

- `apb_bridge.sv` decodes top-level APB addresses into three slaves:
- `0x000` region: always-on power controller
- `0x100` region: 32 kHz timer
- `0x200` region: AES registers/core

### Always-On Power Controller

- `aon_power_ctrl.sv` owns power-domain controls (`pd1_sw_en`, `pd2_sw_en`) and isolation controls (`iso_pd1_n`, `iso_pd2_n`).
- It sequences transitions in ordered phases: pre-off preparation, switch toggling, and post-on restore/de-isolation.
- State enum includes `RUN`, `SLEEP`, `CRYPTO_ONLY`, `DEEP_SLEEP`.
- Current APB control decode actively selects `RUN`, `SLEEP`, and `DEEP_SLEEP`; `CRYPTO_ONLY` is defined in the FSM enum but not selected by the current control register decode path.
- `save_pd2`/`restore_pd2` pulses are generated around PD2 transitions to support retained AES key state.

### Timer Wake Path

- `timer_32k.sv` is a down-counter APB peripheral.
- When enabled and it reaches zero, it reloads and asserts `irq` for wake logic.

### RV32 Domain Behavior

- `rv32_core.sv` is a placeholder execution model, not a full CPU pipeline.
- It emits retire pulses for a short run, then performs one APB write to AES control (`0x230`) and halts.

### AES Register/Core Domain

- `aes_regs.sv` exposes key/data/control/status registers over APB.
- Key words are stored in `ret_ff` wrappers so key state can survive power-down/restore sequences.
- `aes128_iterative.sv` is started by `start & pwr_en` and reports `ready/done` with a 128-bit block output.

## 3) Chiplet System Runtime Logic (`chiplet_extension/`)

### End-to-End Data Path

#### Step A: Plaintext generation and expected-cipher construction (Die A)

- `die_a_system.sv` emits a monotonic 64-bit counter stream.
- Every two 64-bit words are packed into one 128-bit block.
- The same iterative AES-128 core is run locally as a mirror/reference.
- Mirror ciphertext words are pushed into an expected FIFO.
- Returned ciphertext words are compared against this FIFO; mismatch or underflow sets `crypto_error`.

#### Step B: Framing and transmit adaptation

- `flit_packetizer.sv` groups stream words into fixed-size FLIT payloads and appends CRC-8.
- `ucie_tx.sv` accepts FLITs only when:
- link is ready,
- at least one credit is available,
- and no resend is pending.
- It serializes each FLIT into `LANES`-wide beats.

#### Step C: PHY and channel effects

- `phy_behavioral.sv` adds:
- configurable forward/reverse pipeline delay,
- clock jitter toggling,
- probabilistic reverse-path bit-flip error injection.
- `channel_model.sv` adds:
- skew via shift pipelines,
- crosstalk-like stalls when many bits are high,
- reach-based random lane fault injection.

#### Step D: Receive, decrypt service, and return path (Die B)

- `ucie_rx.sv` reassembles lane beats into full FLITs and returns one credit when a FLIT is consumed downstream.
- `flit_depacketizer.sv` checks CRC and emits stream words.
- `die_b_system.sv` accumulates two 64-bit words into one AES block, runs AES-128 iterative encryption, and queues resulting ciphertext words into a return FIFO.
- Outbound ciphertext repeats the same packetizer -> tx -> phy -> channel path back to Die A.

#### Step E: Final check on Die A

- Die A depacketizes the returned stream and compares each word to its expected FIFO.
- `soc_chiplet_top.sv` exposes monitors:
- latest plaintext launched by Die A,
- latest ciphertext observed on Die A return,
- latest ciphertext generated on Die B,
- `crypto_error_flag`.

## 4) Protocol/Control Mechanics

### Credit Flow Control

- `credit_mgr.sv` is a saturating credit counter:
- next = current - debit + return,
- saturates at `[0, MAX_CREDITS]`,
- flags underflow/overflow conditions.

### Link State Machine

- `link_fsm.sv` states: `RESET -> TRAIN -> ACTIVE`, with `RETRAIN` and `DEGRADED` recovery paths.
- Training/retraining timeouts push the link into `DEGRADED`.
- `link_ready` is asserted only when traffic is allowed (no active retry holdoff condition).

### Retry Control

- `retry_ctrl.sv` watches CRC errors and lane-fault/NACK events.
- On error it pulses `resend_request`, increments retry level up to `MAX_RETRIES`, and applies a holdoff counter.
- Without new errors, retry level decays over time.

### CRC and Fault Signaling

- FLIT CRC uses CRC-8 ATM polynomial (`0x07`) in packetizer/depacketizer.
- Lane/channel/PHY faults propagate into adapter fault inputs and can trigger retry/retrain behavior.

## 5) What the Testbenches Prove

### `tb_ucie_prbs.sv`

- Stresses packetizer/adapter/PHY/channel/receiver with PRBS-like source traffic.
- Adds random receive backpressure.
- Selects named directed and randomized tests through `+TEST=<name>`.
- Current PRBS named tests include:
- `prbs_smoke`
- `prbs_credit_starve`
- `prbs_retry_burst`
- `prbs_reset_midflight`
- `prbs_backpressure_wave`
- `prbs_crc_storm`
- `prbs_fault_retrain`
- `prbs_rand_stress`
- Uses:
- scoreboard (`ucie_scoreboard.sv`) for mismatch/drop/latency checks,
- assertions (`credit_checker.sv`, `retry_checker.sv`, `ucie_link_checker.sv`),
- monitor-driven coverage counters (`sim/dv/stats_monitor.sv`) written to CSV.
- Emits machine-readable `DV_RESULT|...` lines for automation.

### `tb_soc_chiplets.sv`

- Runs the full two-die AES loop.
- Builds an *independent* AES reference (`sim/models/aes_ref_pkg.sv`) for expected ciphertext.
- Includes named negative scenarios:
- `soc_wrong_key`
- `soc_misalign`
- Additional named tests include:
- `soc_smoke`
- `soc_backpressure`
- `soc_fault_echo`
- `soc_rand_mix`
- Fails if expected mismatches are absent in negative mode, or present in normal mode.
- Emits machine-readable `DV_RESULT|...` lines for automation.

### Regression Harness

- `scripts/run_regression.py` is the Verilator-native regression entry point.
- It sweeps multiple seeds for randomized tests, compiles bug-mode variants, and
  emits a manifest for every run.
- `scripts/parse_regression_results.py` consumes `DV_RESULT|...` lines and
  assertion/log signatures to build `reports/regress_summary.csv`.
- `scripts/gen_coverage_report.py` aggregates per-run coverage CSVs into
  `reports/coverage_summary.csv`.
- `scripts/gen_failure_summary.py` writes:
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`

## 6) Behavioral Boundaries and Current Practical Notes

- This is a behavioral/prototyping model of a UCIe-like stack, not a sign-off PHY or protocol-complete UCIe implementation.
- The current flow is Verilator-based rather than Icarus-based.
- Stable regression artifacts are generated from named tests and checked in under
  `chiplet_extension/reports/`.
- Packetizer/depacketizer require `(FLIT_WIDTH - CRC_WIDTH)` to be divisible by `DATA_WIDTH`; keep parameters consistent when changing widths.
- Bug-injection macros exist to validate checker sensitivity:
- `UCIE_BUG_CREDIT_OFF_BY_ONE`,
- `UCIE_BUG_CRC_POLY`,
- `UCIE_BUG_RETRY_SEQ`.

## 7) Reading Order for Engineers

If you want to understand behavior quickly, this order is the most direct:

1. `chiplet_extension/rtl/soc_chiplet_top.sv`
2. `chiplet_extension/rtl/soc_die_a_top.sv`
3. `chiplet_extension/rtl/die_a/die_a_system.sv`
4. `chiplet_extension/rtl/soc_die_b_top.sv`
5. `chiplet_extension/rtl/die_b/die_b_system.sv`
6. `chiplet_extension/rtl/d2d_adapter/*.sv`
7. `chiplet_extension/rtl/phy_model/phy_behavioral.sv`
8. `chiplet_extension/rtl/channel_model/channel_model.sv`
9. `chiplet_extension/sim/tb_soc_chiplets.sv` and `chiplet_extension/sim/tb_ucie_prbs.sv`

This path follows exactly how bits move and how correctness is checked.
