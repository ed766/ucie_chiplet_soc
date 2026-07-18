# Formal Appendix - Simulation Assertions and Solver-Backed Proofs

## Scope

The repository keeps two distinct property lanes. `formal-check` runs bounded
Verilator assertion harnesses. `formal-prove` uses a pinned OSS CAD Suite and
SymbiYosys for prove, cover, and mutation-sensitivity tasks. Neither is
commercial formal signoff.

## Solver-Backed Lane

`make -C chiplet_extension formal-prove` runs seven proof families: credit
bounds, APB single-operation behavior, retry identity, DMA completion
accounting, invalid-source containment, power/isolation legality, and async
FIFO safety. Every family has a reachability cover and an expected
counterexample under mutation.

The credit, APB, retry, power, and async-FIFO proofs instantiate real leaf RTL.
DMA accounting and invalid-source containment are architectural contract
proofs, not full `dma_offload_ctrl` proofs. CI pins OSS CAD Suite `2026-07-01`
and verifies its archive checksum before execution.

## What Is Included

- `chiplet_extension/formal/tb_credit_mgr_props.sv`
- `chiplet_extension/formal/tb_link_fsm_props.sv`
- `chiplet_extension/formal/tb_retry_ctrl_props.sv`
- `chiplet_extension/formal/tb_ucie_tx_retry_props.sv`
- `chiplet_extension/formal/tb_flit_crc_props.sv`
- `chiplet_extension/formal/tb_dma_queue_props.sv`
- `chiplet_extension/formal/tb_dma_mem_props.sv`
- `chiplet_extension/formal/tb_power_ctrl_props.sv`
- `chiplet_extension/sim/assertions/chiplet_protocol_assertions.svh`
- `chiplet_extension/sim/tb_axi_lite_csr_wrapper.sv`
- `chiplet_extension/scripts/run_bounded_properties.py`
- `chiplet_extension/reports/formal_summary.csv`
- `docs/reference/assertion_inventory.md`

## Invariants Of Interest

The shared assertion include captures reusable protocol/control intent. The
bounded harnesses instantiate those assertions with concrete DUT signals and
directed stimuli. The main properties are:

- credits stay bounded and saturating
- link FSMs recover from fault or retrain events
- resend requests progress through the retry controller
- replayed FLITs preserve retry identity unless an injected bug says otherwise
- CRC-failed FLITs are blocked from scoreboard-visible commit policy
- DMA queue counts stay bounded and completions require prior accepted work
- accepted-descriptor completions never outpace accepted descriptor count
- FLIT payloads remain stable while the transmitter is backpressured
- IRQ stays level-asserted when enabled completion/error state is pending
- timeout paths produce runtime-error completions
- parity-corrupted memory reads report integrity errors
- invalid source banks abort DMA instead of being consumed silently
- chiplet power-control sidebands match the declared PST/isolation policy
- post-sleep DMA resume-completion observations occur only after restore
- AXI-Lite address/data and response channels remain stable under protocol
  backpressure in the optional CSR-wrapper bench

## How To Read The Evidence

The script compiles each harness with Verilator, runs it, and emits a compact
CSV summary. That makes the result easy to include in the project narrative
without pretending it is a full formal flow.

Current checked-in evidence:

- `8 / 8` nominal bounded-property harnesses meeting expectation
- `1 / 1` expected failing bug-demo harness for `UCIE_BUG_RETRY_SEQ`
- `7 / 7` solver-backed safety proofs
- `7 / 7` reachability covers paired with those proofs
- `7 / 7` expected mutation counterexamples
- `3 / 3` RV32 architectural groups: two pinned `riscv-formal` groups and one
  custom bounded CSR/trap/APB/interrupt group
- the custom RV32 group includes `mscratch` read/write next-state semantics and
  produces an expected counterexample for `RV32_BUG_MSCRATCH_WRITE_DROP`
- DMA completion, timeout, memory-integrity, and power-control invariants now
  have bounded harness coverage in addition to regression coverage

The checked-in harness set is useful in three ways:

- it proves the properties are runnable
- it keeps the logic around replay, credits, DMA retirement, memory integrity,
  and power sequencing explicit
- it adds focused DMA, memory-integrity, CRC-reject, and power-PST invariants
- it provides one bug-demo case for `UCIE_BUG_RETRY_SEQ`

`docs/reference/assertion_inventory.md` is generated from the assertion inventory script
and gives the interview-facing table of assertion name, protected invariant,
harness/checker, and validation status. It includes both bounded SVA harnesses
and simulation-bench protocol assertions such as the AXI-Lite CSR wrapper
checks.

## What It Is Not

- not exhaustive full-chip or commercial formal signoff
- not a replacement for simulation regressions
- not a substitute for broader protocol verification

## Recommended Resume Language

Use language like:

- "added bounded Verilator property checks for credit, retry, and link
  recovery invariants"
- "expanded bounded assertions for DMA queue/completion, memory integrity,
  CRC reject policy, and chiplet power-control sidebands"
- "combined simulation, assertions, coverage, and property checks for chiplet
  link verification"

Avoid language like:

- "proved the chiplet formally"
- "full formal signoff"

## Why It Helps

This appendix makes the project feel more senior because it shows you can move
beyond pass/fail regressions and write the invariants that really matter for a
protocol-oriented design.
