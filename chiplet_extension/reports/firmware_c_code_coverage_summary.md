# Verilator Code Coverage Summary

This is RTL execution evidence from Verilator coverage. It is separate from functional coverage closure and is not commercial coverage signoff.

| Metric | Value |
| --- | ---: |
| Coverage data files | 103 |
| Line points hit | 2478 |
| Line points total | 3035 |
| Overall line coverage proxy | 81.65% |
| Design RTL line coverage proxy | 82.97% |
| Focused component line coverage | 96.49% |
| Focused native branch/expression coverage | 90.00% |
| Focused minimum | 96.00% |
| Focused branch minimum | 85.00% |
| Focused target status | PASS |
| Focused exclusions | None |

## Design RTL Coverage Types

| Coverage type | Hit | Total | Raw coverage | Release target |
| --- | ---: | ---: | ---: | ---: |
| `line` | 543 | 608 | 89.31% | 95% |
| `branch/expression` | 254 | 346 | 73.41% | 85% |

Toggle instrumentation excludes signals wider than 32 bits. The reviewed row additionally excludes only structurally unreachable baseline points and long-horizon diagnostic counters; raw line coverage has no design-RTL exclusions. See `docs/reference/code_coverage_exclusions.md`.

Test contribution ranking: `chiplet_extension/reports/firmware_c_code_coverage_test_ranking.csv`.
Uncovered-point inventory: `chiplet_extension/reports/firmware_c_code_coverage_holes.csv`.

## Uncovered Executable Points

| File | Line | Branch/object |
| --- | ---: | --- |
| `rv32_core.sv` | 168 | `case` |
| `rv32_core.sv` | 225 | `case` |
| `rv32_core.sv` | 602 | `case` |
| `rv32_core.sv` | 715 | `elsif` |
| `rv32_core.sv` | 779 | `case` |
| `rv32_core.sv` | 794 | `case` |
| `credit_mgr.sv` | 44 | `elsif` |
| `credit_mgr.sv` | 47 | `if` |
| `link_fsm.sv` | 50 | `if` |
| `link_fsm.sv` | 64 | `case` |
| `link_fsm.sv` | 66 | `elsif` |
| `link_fsm.sv` | 69 | `else` |
| `link_fsm.sv` | 69 | `if` |
| `link_fsm.sv` | 76 | `case` |
| `link_fsm.sv` | 78 | `elsif` |
| `link_fsm.sv` | 81 | `else` |
| `link_fsm.sv` | 81 | `if` |
| `link_fsm.sv` | 88 | `case` |
| `retry_ctrl.sv` | 38 | `elsif` |
| `ucie_tx.sv` | 76 | `elsif` |
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
| `design_rtl` | 1890 | 2278 | 82.97% |
| `optional_collateral_rtl` | 24 | 25 | 96.00% |
| `checker_monitor` | 24 | 30 | 80.00% |
| `testbench` | 502 | 663 | 75.72% |
| `other` | 38 | 39 | 97.44% |

## Component Coverage

| Component | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `axi_lite_bridge` | NA | NA | NA |
| `cdc_rdc_collateral` | NA | NA | NA |
| `credit_manager` | 19 | 24 | 79.17% |
| `rv32_core` | 538 | 559 | 96.24% |
| `apb_dma_csr_bridge` | 24 | 25 | 96.00% |
| `rv32_rom_feeder` | 16 | 16 | 100.00% |
| `soc_chiplet_rv32_top` | 27 | 27 | 100.00% |

## Top Uncovered Design RTL Files

| File | Hit | Total | Missing | Coverage |
| --- | ---: | ---: | ---: | ---: |
| `dma_offload_ctrl.sv` | 444 | 703 | 259 | 63.16% |
| `die_a_system.sv` | 28 | 65 | 37 | 43.08% |
| `link_fsm.sv` | 25 | 51 | 26 | 49.02% |
| `rv32_core.sv` | 538 | 559 | 21 | 96.24% |
| `ucie_tx.sv` | 39 | 47 | 8 | 82.98% |
| `retry_ctrl.sv` | 15 | 23 | 8 | 65.22% |
| `die_b_system.sv` | 47 | 54 | 7 | 87.04% |
| `phy_behavioral.sv` | 55 | 60 | 5 | 91.67% |

- LCOV-style info: `chiplet_extension/reports/firmware_c_code_coverage.info`
- Annotated output: `chiplet_extension/build/firmware_c/code_coverage_annotated`
