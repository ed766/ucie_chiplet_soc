# Verilator Code Coverage Summary

This is RTL execution evidence from Verilator coverage. It is separate from functional coverage closure and is not commercial coverage signoff.

| Metric | Value |
| --- | ---: |
| Coverage data files | 85 |
| Line points hit | 2310 |
| Line points total | 2817 |
| Overall line coverage proxy | 82.00% |
| Design RTL line coverage proxy | 83.20% |
| Focused component line coverage | 96.27% |
| Focused native branch/expression coverage | 93.10% |
| Focused minimum | 96.00% |
| Focused branch minimum | 85.00% |
| Focused target status | PASS |
| Focused exclusions | None |

## Design RTL Coverage Types

| Coverage type | Hit | Total | Raw coverage | Release target |
| --- | ---: | ---: | ---: | ---: |
| `line` | 514 | 575 | 89.39% | 95% |
| `branch/expression` | 243 | 326 | 74.54% | 85% |

Toggle instrumentation excludes signals wider than 32 bits. The reviewed row additionally excludes only structurally unreachable baseline points and long-horizon diagnostic counters; raw line coverage has no design-RTL exclusions. See `docs/reference/code_coverage_exclusions.md`.

Test contribution ranking: `chiplet_extension/reports/firmware_c_code_coverage_test_ranking.csv`.
Uncovered-point inventory: `chiplet_extension/reports/firmware_c_code_coverage_holes.csv`.

## Uncovered Executable Points

| File | Line | Branch/object |
| --- | ---: | --- |
| `rv32_core.sv` | 131 | `case` |
| `rv32_core.sv` | 133 | `case` |
| `rv32_core.sv` | 134 | `case` |
| `rv32_core.sv` | 135 | `case` |
| `rv32_core.sv` | 146 | `case` |
| `rv32_core.sv` | 180 | `case` |
| `rv32_core.sv` | 471 | `case` |
| `rv32_core.sv` | 567 | `elsif` |
| `credit_mgr.sv` | 44 | `elsif` |
| `credit_mgr.sv` | 47 | `if` |
| `link_fsm.sv` | 50 | `if` |
| `link_fsm.sv` | 69 | `else` |
| `link_fsm.sv` | 69 | `if` |
| `link_fsm.sv` | 76 | `case` |
| `link_fsm.sv` | 78 | `elsif` |
| `link_fsm.sv` | 81 | `else` |
| `link_fsm.sv` | 81 | `if` |
| `link_fsm.sv` | 88 | `case` |
| `die_a_system.sv` | 126 | `block` |
| `die_a_system.sv` | 161 | `elsif` |
| `dma_offload_ctrl.sv` | 404 | `case` |
| `dma_offload_ctrl.sv` | 405 | `case` |
| `dma_offload_ctrl.sv` | 406 | `case` |
| `dma_offload_ctrl.sv` | 407 | `case` |
| `dma_offload_ctrl.sv` | 408 | `case` |
| `dma_offload_ctrl.sv` | 413 | `case` |
| `dma_offload_ctrl.sv` | 414 | `case` |
| `dma_offload_ctrl.sv` | 418 | `case` |
| `dma_offload_ctrl.sv` | 419 | `case` |
| `dma_offload_ctrl.sv` | 437 | `case` |

## Reviewed Toggle Hotspots

| File | Signal family | Missing points |
| --- | --- | ---: |

## Reviewed Toggle Exclusions

| Rationale | Excluded points |
| --- | ---: |

Full-design release targets: **NOT ENFORCED** for this focused/diagnostic lane.
Threshold enforcement for this invocation: **disabled**.

## Coverage By Source Group

| Source group | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `design_rtl` | 1778 | 2137 | 83.20% |
| `optional_collateral_rtl` | 24 | 25 | 96.00% |
| `checker_monitor` | 24 | 30 | 80.00% |
| `testbench` | 476 | 617 | 77.15% |
| `other` | 8 | 8 | 100.00% |

## Component Coverage

| Component | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `axi_lite_bridge` | NA | NA | NA |
| `cdc_rdc_collateral` | NA | NA | NA |
| `credit_manager` | 19 | 24 | 79.17% |
| `rv32_core` | 432 | 450 | 96.00% |
| `apb_dma_csr_bridge` | 24 | 25 | 96.00% |
| `rv32_rom_feeder` | 16 | 16 | 100.00% |
| `soc_chiplet_rv32_top` | 19 | 19 | 100.00% |

## Top Uncovered Design RTL Files

| File | Hit | Total | Missing | Coverage |
| --- | ---: | ---: | ---: | ---: |
| `dma_offload_ctrl.sv` | 444 | 703 | 259 | 63.16% |
| `die_a_system.sv` | 28 | 65 | 37 | 43.08% |
| `link_fsm.sv` | 32 | 51 | 19 | 62.75% |
| `rv32_core.sv` | 432 | 450 | 18 | 96.00% |
| `die_b_system.sv` | 47 | 54 | 7 | 87.04% |
| `phy_behavioral.sv` | 55 | 60 | 5 | 91.67% |
| `credit_mgr.sv` | 19 | 24 | 5 | 79.17% |
| `chiplet_power_ctrl.sv` | 58 | 62 | 4 | 93.55% |

- LCOV-style info: `chiplet_extension/reports/firmware_c_code_coverage.info`
- Annotated output: `chiplet_extension/build/firmware_c/code_coverage_annotated`
