# Verilator Code Coverage Summary

This is RTL execution evidence from Verilator coverage. It is separate from functional coverage closure and is not commercial coverage signoff.

| Metric | Value |
| --- | ---: |
| Coverage data files | 12 |
| Line points hit | 1907 |
| Line points total | 2349 |
| Overall line coverage proxy | 81.18% |
| Design RTL line coverage proxy | 80.19% |
| Focused component line coverage | 86.62% |
| Focused minimum | 85.00% |
| Focused exclusions | None |

## Coverage By Source Group

| Source group | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `design_rtl` | 1530 | 1908 | 80.19% |
| `optional_collateral_rtl` | 24 | 25 | 96.00% |
| `checker_monitor` | 24 | 30 | 80.00% |
| `testbench` | 329 | 386 | 85.23% |

## Component Coverage

| Component | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `axi_lite_bridge` | NA | NA | NA |
| `cdc_rdc_collateral` | NA | NA | NA |
| `credit_manager` | 19 | 24 | 79.17% |
| `rv32_core` | 188 | 225 | 83.56% |
| `apb_dma_csr_bridge` | 24 | 25 | 96.00% |
| `rv32_rom_feeder` | 16 | 16 | 100.00% |
| `soc_chiplet_rv32_top` | 18 | 18 | 100.00% |

## Top Uncovered Design RTL Files

| File | Hit | Total | Missing | Coverage |
| --- | ---: | ---: | ---: | ---: |
| `dma_offload_ctrl.sv` | 466 | 700 | 234 | 66.57% |
| `rv32_core.sv` | 188 | 225 | 37 | 83.56% |
| `die_a_system.sv` | 28 | 65 | 37 | 43.08% |
| `link_fsm.sv` | 25 | 51 | 26 | 49.02% |
| `ucie_tx.sv` | 39 | 47 | 8 | 82.98% |
| `retry_ctrl.sv` | 15 | 23 | 8 | 65.22% |
| `die_b_system.sv` | 47 | 54 | 7 | 87.04% |
| `phy_behavioral.sv` | 55 | 60 | 5 | 91.67% |

- LCOV-style info: `chiplet_extension/reports/firmware_code_coverage.info`
- Annotated output: `chiplet_extension/build/code_coverage_annotated`
