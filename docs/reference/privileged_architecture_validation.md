# Privileged Architecture Validation

This separately reported compiled-C lane validates the machine-mode architecture added after external Spike/ACT4 review. It reuses the GCC build, RTL execution, RVFI trace, and independent local ISS without changing canonical chiplet closure metrics.

- Named scenarios: **8 / 8**
- Privileged functional points: **32 / 32**
- Same-window privileged crosses: **16 / 16**

| Scenario | Purpose | Result |
| --- | --- | ---: |
| `misa_mtval_csr_matrix` | `misa mtval csr matrix` | PASS |
| `illegal_instruction_mtval` | `illegal instruction mtval` | PASS |
| `misaligned_load_mtval` | `misaligned load mtval` | PASS |
| `store_access_fault_mtval` | `store access fault mtval` | PASS |
| `mtvec_direct_exception` | `mtvec direct exception` | PASS |
| `mtvec_vectored_timer` | `mtvec vectored timer` | PASS |
| `mtvec_vectored_external` | `mtvec vectored external` | PASS |
| `mret_state_restore` | `mret state restore` | PASS |

## Evidence Layers

- Firmware self-checks validate software-visible CSR, trap, vector, and return behavior.
- The repository-local ISS independently predicts trap cause/value, PC targets, CSR state, and suppressed side effects from each RVFI transaction.
- Five named simulation assertions check synchronous base targeting, vectored interrupt targeting, interrupt-zero `mtval`, address-fault `mtval`, and illegal-instruction `mtval`.
- The custom SymbiYosys harness checks the same contracts over unconstrained instruction and operand values at its documented bound.
- Three true RTL mutations validate sensitivity to zeroed `mtval`, direct-only interrupt entry, and writable `misa`.

## Defects Closed

This lane exposed an RVFI trace bug that replaced nonzero synchronous `mtval` with stale CSR state. The formal property set also exposed incorrect CSRRS/CSRRC write-intent decoding for a nonzero source register containing zero. Both RTL defects are fixed and retained as regression properties.

The lane checks read-only `misa`, writable `mtval`, Direct/Vectored `mtvec` WARL behavior, exception/interrupt target selection, precise trap values, and `MRET` state restoration. Results are open-source pre-silicon evidence, not RISC-V certification.
