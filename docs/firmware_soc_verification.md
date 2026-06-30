# Firmware-Driven RV32 SoC Verification

The lightweight RV32 core executes ROM-backed assembly and controls the chiplet DMA through APB MMIO. Testbench CSR writes are not used in this lane.

| Scenario | Status | Cycles | MMIO reads/writes | Wait cycles | Bus errors | DMA accepted/completed |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `dma_smoke` | `PASS` | 210 | 15 / 8 | 0 | 0 | 1 / 1 |
| `dma_back_to_back` | `PASS` | 263 | 17 / 13 | 0 | 0 | 2 / 2 |
| `crypto_only_reject` | `PASS` | 71 | 1 / 5 | 0 | 0 | 0 / 1 |
| `apb_wait_error` | `PASS` | 50 | 3 / 0 | 9 | 2 | 0 / 0 |
| `sleep_resume` | `PASS` | 227 | 16 / 7 | 23 | 0 | 1 / 1 |
| `irq_pending_then_enable` | `PASS` | 212 | 15 / 9 | 0 | 0 | 1 / 1 |
| `queue_full_reject` | `PASS` | 247 | 3 / 25 | 0 | 0 | 5 / 1 |
| `completion_fifo_stall` | `PASS` | 597 | 36 / 26 | 0 | 0 | 5 / 5 |
| `timeout_error` | `PASS` | 1124 | 131 / 7 | 0 | 0 | 1 / 1 |
| `parity_source_error` | `PASS` | 120 | 3 / 8 | 0 | 0 | 1 / 1 |
| `deep_sleep_invalid_source` | `PASS` | 112 | 3 / 6 | 20 | 0 | 1 / 1 |
| `apb_reset_mid_wait` | `PASS` | 220 | 10 / 7 | 51 | 0 | 1 / 1 |

Firmware/MMIO coverage: **30 / 30** required points.
Firmware outcome/power crosses: **7 / 7** required crosses.
Focused RV32/APB/ROM integration line coverage: **86.62%**.

## Evidence Boundary

- The program uses the intentionally small instruction subset supported by `rv32_core`.
- APB accesses stall instruction retirement until `PREADY`; invalid MMIO produces `bus_error`.
- The main chiplet data path remains the behavioral UCIe-style link; AXI-Lite remains optional external CSR collateral.
- This is behavioral open-source simulation evidence, not commercial SoC or power-aware signoff.
