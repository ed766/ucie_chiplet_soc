# UCIe Chiplet Extension for the Power-Aware RISC-V SoC

`chiplet_extension/` turns the original single-die RISC-V SoC into a dual-die
system linked by a behavioral UCIe-style fabric. Die A produces plaintext
traffic, packetizes it into CRC-protected FLITs, and checks the returned
ciphertext. Die B receives the traffic, runs AES-128 encryption, and sends the
result back across the link.

The verification environment stays intentionally lightweight. It does not try to
be full UVM. Instead, it upgrades the original benches into a coverage-driven DV
project built around named tests, passive monitors, scoreboards, assertions,
machine-readable result lines, and Python-generated regression dashboards.

## Layout

- `rtl/`
  - Dual-die RTL, packetizer/depacketizer, credit manager, retry logic, UCIe
    Tx/Rx, PHY/channel models, and `soc_chiplet_top.sv`
- `sim/`
  - `tb_ucie_prbs.sv` for link-level PRBS traffic
  - `tb_soc_chiplets.sv` for the full Die A -> Die B -> Die A datapath
  - `dv/` for shared config, coverage, and stats packages
  - `tests/` for named directed and randomized scenarios
  - `checkers/` and `scoreboard/` for assertions, monitors, and checking
- `scripts/`
  - Verilator regression runner plus CSV/Markdown post-processing scripts
- `reports/`
  - Generated regression summary, coverage summary, failure buckets, dashboard,
    and per-run coverage / scoreboard CSVs
- `openlane/`
  - LibreLane/OpenLane2 configuration for `soc_chiplet_top`
- `upf/`
  - Dual-die UPF scaffolding for always-on vs. switchable domains

## Verification Methodology

### Benches

- `tb_ucie_prbs.sv`
  - Drives the packetizer, adapter, PHY, and channel path with PRBS-derived
    traffic
  - Exercises credit starvation, backpressure, reset, and retry-oriented
    scenarios
- `tb_soc_chiplets.sv`
  - Runs the complete two-die AES datapath
  - Checks returned ciphertext against an independent reference path
  - Includes negative scenarios such as wrong-key and misalignment checks

### Lightweight DV infrastructure

- `sim/dv/txn_pkg.sv`
  - Lightweight config objects and plusarg-driven runtime knobs
- `sim/dv/stats_pkg.sv`
  - Standardized machine-readable `DV_RESULT|...` lines
- `sim/dv/stats_monitor.sv`
  - Monitor-driven functional coverage counters and per-run CSV emission
- `sim/dv/ucie_cov_pkg.sv`
  - Coverage bin accounting shared between benches and Python reporting

### Checking

- `sim/checkers/credit_checker.sv`
  - Credit accounting assertions and bug-mode detection
- `sim/checkers/retry_checker.sv`
  - Retry/resend behavior checks
- `sim/checkers/ucie_link_checker.sv`
  - Bounded training and progress assertions
- `sim/scoreboard/ucie_txn_monitor.sv`
  - Passive FLIT-level monitor
- `sim/scoreboard/ucie_scoreboard.sv`
  - Queue-based FLIT scoreboard with latency tracking

### Coverage intent

Coverage is portable and simulator-friendly by design. The benches do not rely
on UCIS databases. Instead, `stats_monitor.sv` writes CSV coverage counters for:

- link FSM state visibility
- credit regions
- backpressure
- retry / CRC / lane-fault hooks
- latency buckets
- end-to-end update and mismatch behavior
- visible reset / idle proxies

The Python scripts aggregate those per-run CSVs into
`reports/coverage_summary.csv`.

## Named Tests

The environment currently ships with 15 named tests:

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

The stable suite is what generates the checked-in dashboard artifacts. The
stress suite is intentionally kept separate because it is currently useful as an
exploratory recovery-stress workload, not as a clean default pass target.

## Running the DV Flow

From `chiplet_extension/`:

```bash
# Quick smoke run for both benches
make chiplet-sim

# Full default regression (stable suite + bug validation)
make regress

# Exploratory retry/fault stress suite
make stress

# Bug-validation-only sweep
make bug-validate
```

Equivalent direct script usage:

```bash
python3 scripts/run_regression.py
python3 scripts/run_regression.py --suite stress
python3 scripts/run_regression.py --suite bug
```

The flow uses Verilator.

Verified in this workspace on March 30, 2026: `make regress` was rerun after
the latest synthesis-compatible RTL cleanup and the stable suite still finished
with 14 / 14 runs meeting expectation.

## Result Format and Reports

Each passing run emits a standardized result line like:

```text
DV_RESULT|bench=tb_ucie_prbs|test=prbs_smoke|scenario=directed|seed=...|status=PASS|...
```

`scripts/parse_regression_results.py` turns those lines plus assertion/log
signatures into `reports/regress_summary.csv`. The other report scripts then
generate:

- `reports/coverage_summary.csv`
- `reports/failure_buckets.csv`
- `reports/top_failures.md`
- `reports/verification_dashboard.md`

Per-run artifacts also land in `reports/`:

- `*_coverage.csv`
- `*_scoreboard.csv`

## Current Stable Regression Snapshot

The checked-in reports were regenerated from the Verilator stable suite on
March 30, 2026.

- Total runs: 14
- Runs meeting expectation: 14
- Nominal pass rate: 13 / 13
- Randomized runs meeting expectation: 4 / 4
- Expected bug-validation failures: 1
- Stable functional coverage: 11 / 23 bins (47.8%)

The bug-validation result is:

- `bug_credit_off_by_one` with `UCIE_BUG_CREDIT_OFF_BY_ONE`
  - observed status: `FAIL`
  - bucket: `credit_accounting`

## Known Gaps

- Retry / CRC / lane-fault bins are modeled and tracked, but they are not yet
  covered by the default stable suite.
- The exploratory stress tests currently bucket as `link_progress` under heavy
  retry churn and are kept out of the default pass gate until that recovery
  behavior is tightened.
- Power-state coverage is proxy-based (`reset` / `idle`) rather than true
  UPF-aware power simulation.

These limitations are documented on purpose. The project is meant to show a DV
workflow with clear evidence, not to pretend the coverage story is finished.

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

The physical-design flow is separate from the DV benches. The verification
packages and test-only files live under `sim/` and do not enter the synthesis
file list used by LibreLane.

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
