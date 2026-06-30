# Power Verification Plan - UCIe Chiplet DV

## Goal

Verify the chiplet power-intent story with explicit, readable evidence while
separating three different layers:

- RTL proxy power behavior verified by Verilator tests
- tool-neutral UPF 4.0 power intent for domains, supplies, switches,
  isolation, retention, and PST
- signoff gap: no commercial UPF-aware simulation or implementation flow has
  been run in this repo

The runnable behavioral verification remains UPF-aligned proxy verification:

- run
- crypto-only
- sleep entry/exit
- deep-sleep recovery
- DMA sleep/resume completion
- isolation blocking and wake release
- power transition under link backpressure
- unavailable-domain access rejection
- memory retention and invalidation behavior

These scenarios are valuable because they prove the DV environment can see
state transitions, domain availability, isolation effects, retention behavior,
illegal activity, and recovery behavior at the SoC level.

The declarative power intent is captured in:

- `chiplet_extension/upf/chiplet_full.upf`

That UPF package defines `AON_CHIPLET`, switchable Die A traffic/DMA/link
domains, switchable Die B crypto/link domains, the switchable channel domain,
power switches, clamp-to-0 output isolation, DMA sleep-context retention, DMA
memory-bank retention capability, and the RUN / CRYPTO_ONLY / SLEEP /
DEEP_SLEEP power-state table. The compatibility files `die_a.upf`,
`die_b.upf`, and `pst_chiplet.upf` source the canonical intent.

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
- isolation assertion while source domains are unavailable
- post-wake de-isolation and clean traffic restart
- DMA control/queue retention across SLEEP -> RUN
- DMA memory retained/invalid bank behavior across low-power transitions
- legal versus illegal cross-die activity
- transition behavior while link backpressure or DMA activity is present
- recovery back into run mode
- per-domain switch on/off sequencing
- per-domain isolation assert/deassert sequencing
- isolation-before-switch-off and restore-before-de-isolation ordering

### Functional coverage model

`power_state_monitor.sv` is a passive, UVM-style monitor. It does not drive the
design. The SoC bench connects the internal `u_chiplet.u_pwr_ctrl` sidebands by
hierarchical reference so the monitor can observe switch, isolation, retention,
and activity state without adding public top-level ports.

The monitor includes simulator-native covergroups/coverpoints for tools that
support them and a Verilator-compatible counter mirror that feeds
`power_state_summary.csv`.

Coverage targets:

- PST state coverpoint: RUN, CRYPTO_ONLY, SLEEP, DEEP_SLEEP
- transition coverpoint: RUN<->CRYPTO_ONLY, RUN<->SLEEP, RUN<->DEEP_SLEEP
- valid domain-combo coverpoint: RUN, CRYPTO_ONLY, SLEEP, DEEP_SLEEP PST
  combinations
- isolation coverpoint: asserted, deasserted, blocked traffic, release traffic
- retention coverpoint: DMA sleep save/restore and DMA memory save/restore
- activity coverpoint: no traffic, link traffic, DMA queued, DMA active,
  completion/IRQ pending
- switch-domain coverpoint: on/off observations for each switchable domain
- isolation-domain coverpoint: assert/deassert observations for each
  switchable domain
- sequencing coverpoint: isolation before switch-off, switch-on before
  restore, restore before de-isolation, and single-cycle retention pulses
- crosses: state x domain combo, transition x activity, isolation x activity

This is functional proxy coverage. It is intentionally separate from
`upf-check`, which validates static UPF structure but does not contribute
functional coverage.

## Named Tests

- `power_run_mode`
- `power_crypto_only`
- `power_sleep_entry_exit`
- `power_deep_sleep_recover`
- `power_isolation_blocks_tx`
- `power_wakeup_releases_isolation_cleanly`
- `power_transition_with_link_backpressure`
- `power_illegal_access_error_response`
- `dma_power_sleep_resume_queue`
- `power_traffic_cross_test`
- `power_iso_before_switch_off`
- `power_restore_before_deiso`
- `power_domain_sequence_matrix`
- `power_invalid_transition_clamped`
- `dma_sleep_during_queued_work`
- `dma_sleep_during_active_transfer`
- `dma_power_state_retention_matrix`
- `dma_crypto_only_submit_blocked`
- `mem_sleep_retained_bank`
- `mem_sleep_nonretained_bank`
- `mem_sleep_dst_nonretained_bank`
- `mem_nonretained_readback_poison_clean`
- `mem_invalid_clear_on_write`
- `mem_deep_sleep_retention_matrix`
- `mem_crypto_only_cfg_access`

These are separate named tests rather than bench edits, so the regression can
sweep them like any other scenario.

## Monitored Evidence

The power monitor and result flow write a checked-in CSV summary:

- `chiplet_extension/reports/power_state_summary.csv`

The regression dashboard also includes a power section:

- `chiplet_extension/reports/verification_dashboard.md`

The UPF structure can be checked with:

- `make -C chiplet_extension upf-check`

This target statically checks UPF version, expected domains, power switches,
output isolation, DMA retention strategies, PST values, and RTL hierarchy /
control references. It also writes:

- `chiplet_extension/reports/upf_intent_summary.md`

This is a repo-local intent sanity check, not a replacement for UPF-aware
elaboration.

The current checked-in evidence shows:

- `26 / 26` low-power proxy tests meeting expectation
- all four modeled states visited
- all six modeled transitions visited
- all four valid PST domain-combo bins visited
- all four isolation bins visited
- all four DMA retention bins visited
- all five selected transition/activity bins visited
- all twelve per-domain switch on/off bins visited
- all twelve per-domain isolation assert/deassert bins visited
- all four sequencing bins visited with zero sequencing violations
- queued-DMA sleep/resume completes with IRQ and golden-image compare
- retained SLEEP behavior and cleared DEEP_SLEEP behavior are both exercised
- `CRYPTO_ONLY` submission blocking is checked in the DMA-focused
  `dma_crypto_only_submit_blocked` test while reads and completion drain remain
  available

## How This Should Be Described

Use language like:

- "UPF-aligned power-intent proxy verification"
- "tool-neutral UPF 4.0 power intent"
- "power-state behavior checked with explicit low-power scenarios"
- "proxy verification for run, sleep, and crypto-only operation"
- "DMA sleep/resume verification using the same proxy power model"
- "not yet signoff-validated by a UPF-aware commercial tool"

Avoid language that implies:

- true UPF-aware simulation
- signoff-quality low-power closure
- supply-network verification in the physical-design sense

## Practical Limitations

- Behavioral verification still models power intent through bench behavior and
  monitor checks.
- `chiplet_full.upf` is complete declarative intent, but not a commercial
  UPF-aware simulation, synthesis, or implementation result.
- This is intentionally lighter than a full low-power tool flow.
- That tradeoff keeps the project realistic and easy to run under Verilator.

## Why It Matters For Hiring

Low-power verification is a strong resume signal because it shows you can work
across architecture, RTL behavior, and verification intent. Even as a proxy
flow, it tells the reader that you understand power-state modeling and can
prove it with runnable evidence.
