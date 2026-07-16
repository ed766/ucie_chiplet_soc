# Code Coverage Exclusion Policy

The Verilator code-coverage lane reports line, branch/expression, toggle, user,
and FSM evidence separately from functional coverage. Exclusions are reviewed,
not silently applied to improve a headline percentage.

| Exclusion | Coverage type | Rationale |
| --- | --- | --- |
| Signals wider than 32 bits | Toggle only | Wide FLIT payloads, SRAM data arrays, and AES state create data-dependent toggle noise rather than control-path evidence. Line and functional checking remain enabled. |
| Testbench fatal/error branches | Code coverage report grouping | These are negative checker outcomes, not reachable nominal DUT behavior. Bug-validation tests independently sensitize them. |
| Compile-time structural alternatives | Default-configuration target only | One-bank and parity-disabled variants are reported by characterization rather than counted as holes in the checked-in two-bank/parity-enabled baseline. |
| Fixed credit-width bits | Toggle only | Credit debit/return events are unit-valued, initialization is fixed, and bit 8 or above cannot toggle when the baseline `MAX_CREDITS` is 128. |
| High bits of saturating diagnostic counters | Toggle only | Parity/conflict/wait/reject counters would require impractically long repetition to toggle upper bits; their functional increment and saturation behavior is checked separately. |
| Hardwired channel fault-pipeline bits | Toggle only | The baseline channel pipeline explicitly shifts `1'b0`; directed lane faults enter through the adapter/proxy path instead of these reserved pipeline fields. |
| Disabled probabilistic PHY injection state | Toggle only | The checked-in baseline sets `ERROR_PROB_NUM=0`; deterministic CRC and lane-fault tests cover recovery without enabling nondeterministic PHY corruption. |

No executable design-RTL line is excluded from the raw report. Adjusted release
targets must show raw and reviewed values side by side; the canonical `60 / 60`
functional target is unaffected.

The reviewed gate is enforced only by the main `code-coverage` target. Component
and firmware coverage commands continue to report their own scoped metrics.
