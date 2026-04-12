# Formal Appendix - Bounded Verilator Property Checks

## Scope

This appendix is intentionally small and practical. It does not claim full
theorem-proving formal signoff. Instead, it adds a compact set of bounded
Verilator assertion harnesses that strengthen the DV story without changing
the project methodology.

## What Is Included

- `chiplet_extension/formal/tb_credit_mgr_props.sv`
- `chiplet_extension/formal/tb_link_fsm_props.sv`
- `chiplet_extension/formal/tb_retry_ctrl_props.sv`
- `chiplet_extension/formal/tb_ucie_tx_retry_props.sv`
- `chiplet_extension/scripts/run_bounded_properties.py`
- `chiplet_extension/reports/formal_summary.csv`

## Invariants Of Interest

The harnesses are focused on a few protocol-level properties:

- credits stay bounded and saturating
- link FSMs recover from fault or retrain events
- resend requests progress through the retry controller
- replayed FLITs preserve retry identity unless an injected bug says otherwise

## How To Read The Evidence

The script compiles each harness with Verilator, runs it, and emits a compact
CSV summary. That makes the result easy to include in the project narrative
without pretending it is a full formal flow.

Current checked-in evidence:

- `4 / 4` nominal bounded-property harnesses meeting expectation
- `1 / 1` expected failing bug-demo harness for `UCIE_BUG_RETRY_SEQ`
- DMA completion and timeout behavior are verified in the regression flow,
  separate from this bounded appendix

The checked-in harness set is useful in three ways:

- it proves the properties are runnable
- it keeps the logic around replay, credits, and link recovery explicit
- it provides one bug-demo case for `UCIE_BUG_RETRY_SEQ`

## What It Is Not

- not a SymbiYosys or theorem-proving formal signoff flow
- not a replacement for simulation regressions
- not a substitute for broader protocol verification

## Recommended Resume Language

Use language like:

- "added bounded Verilator property checks for credit, retry, and link
  recovery invariants"
- "combined simulation, assertions, coverage, and property checks for chiplet
  link verification"

Avoid language like:

- "proved the chiplet formally"
- "full formal signoff"

## Why It Helps

This appendix makes the project feel more senior because it shows you can move
beyond pass/fail regressions and write the invariants that really matter for a
protocol-oriented design.
