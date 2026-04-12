# Power Verification Plan - UCIe Chiplet DV

## Goal

Verify the chiplet power-intent story with explicit, readable evidence instead
of pretending the project already has full UPF-aware simulation. The power
verification here is UPF-aligned proxy verification:

- run
- crypto-only
- sleep entry/exit
- deep-sleep recovery
- DMA sleep/resume completion

These scenarios are valuable because they prove the DV environment can see
state transitions, illegal activity, and recovery behavior at the SoC level.

## What Is Being Verified

### State coverage

- run mode
- crypto-only mode
- sleep mode
- deep-sleep mode

### Transition coverage

- run -> crypto-only
- crypto-only -> run
- run -> sleep
- sleep -> run
- run -> deep-sleep
- deep-sleep -> run

### Behavior checks

- isolation-like behavior during off/proxy states
- retention-like expectations around crypto state
- legal versus illegal cross-die activity
- recovery back into run mode

## Named Tests

- `power_run_mode`
- `power_crypto_only`
- `power_sleep_entry_exit`
- `power_deep_sleep_recover`
- `dma_power_sleep_resume_queue`
- `dma_power_state_retention_matrix`

These are separate named tests rather than bench edits, so the regression can
sweep them like any other scenario.

## Monitored Evidence

The power monitor and result flow write a checked-in CSV summary:

- `chiplet_extension/reports/power_state_summary.csv`

The regression dashboard also includes a power section:

- `chiplet_extension/reports/verification_dashboard.md`

The current checked-in evidence shows:

- `6 / 6` power-proxy tests meeting expectation
- all four modeled states visited
- all six modeled transitions visited
- queued-DMA sleep/resume completes with IRQ and golden-image compare
- retained SLEEP behavior and cleared DEEP_SLEEP behavior are both exercised
- `CRYPTO_ONLY` submission blocking is checked in the DMA-focused
  `dma_crypto_only_submit_blocked` test while reads and completion drain remain
  available

## How This Should Be Described

Use language like:

- "UPF-aligned power-intent proxy verification"
- "power-state behavior checked with explicit low-power scenarios"
- "proxy verification for run, sleep, and crypto-only operation"
- "DMA sleep/resume verification using the same proxy power model"

Avoid language that implies:

- true UPF-aware simulation
- signoff-quality low-power closure
- supply-network verification in the physical-design sense

## Practical Limitations

- The project still models power intent through bench behavior and monitor
  checks.
- This is intentionally lighter than a full low-power tool flow.
- That tradeoff keeps the project realistic and easy to run under Verilator.

## Why It Matters For Hiring

Low-power verification is a strong resume signal because it shows you can work
across architecture, RTL behavior, and verification intent. Even as a proxy
flow, it tells the reader that you understand power-state modeling and can
prove it with runnable evidence.
