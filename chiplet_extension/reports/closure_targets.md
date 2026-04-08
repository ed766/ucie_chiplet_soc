# Verification Closure Targets

## Current Snapshot

- Stable runs recorded: 16
- Expected bug-validation failures observed: 3

## Closure Wins

- Deterministic retry / CRC / lane-fault tests are part of the named-test flow.
- Bug validation now covers credit accounting, CRC integrity, and retry identity.
- End-to-end SoC checking uses a file-backed Python golden-model reference path.

## Remaining Uncovered Bins

- `credit_low` (credits)
- `retry_backpressure_cross` (backpressure)
- `latency_low` (latency)
- `latency_high` (latency)
- `expected_empty` (end_to_end)

## Why These Remain Open

- `credit_low`, `retry_backpressure_cross`, and `latency_low` are observable in
  exploratory SoC fault-recovery scenarios, but those scenarios are not yet
  stable enough to promote into the default green gate.
- `latency_high` appears in some retry-heavy PRBS seeds, but not yet as a
  deterministic, named, stable-suite check.
- `expected_empty` needs a dedicated negative end-to-end case that intentionally
  exhausts the Python-generated reference stream without turning the default
  nominal suite into a misleading red test.
