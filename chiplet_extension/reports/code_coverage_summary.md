# Verilator Code Coverage Summary

This is RTL execution evidence from Verilator coverage. It is separate from functional coverage closure and is not commercial coverage signoff.

| Metric | Value |
| --- | ---: |
| Coverage data files | 98 |
| Line points hit | 5381 |
| Line points total | 7242 |
| Overall line coverage proxy | 74.30% |
| Design RTL line coverage proxy | 93.26% |




## Design RTL Coverage Types

| Coverage type | Hit | Total | Raw coverage | Release target |
| --- | ---: | ---: | ---: | ---: |
| `line` | 513 | 533 | 96.25% | 95% |
| `branch/expression` | 307 | 344 | 89.24% | 85% |
| `toggle` | 1933 | 2570 | 75.21% | diagnostic |
| `toggle_reviewed` | 1910 | 2116 | 90.26% | 90% (MET) |

Toggle instrumentation excludes signals wider than 32 bits. The reviewed row additionally excludes only structurally unreachable baseline points and long-horizon diagnostic counters; raw line coverage has no design-RTL exclusions. See `docs/code_coverage_exclusions.md`.

Test contribution ranking: `chiplet_extension/reports/code_coverage_test_ranking.csv`.
Uncovered-point inventory: `chiplet_extension/reports/code_coverage_holes.csv`.

## Uncovered Executable Points

| File | Line | Branch/object |
| --- | ---: | --- |
| `credit_mgr.sv` | 44 | `elsif` |
| `credit_mgr.sv` | 44 | `elsif` |
| `credit_mgr.sv` | 47 | `if` |
| `credit_mgr.sv` | 47 | `if` |
| `link_fsm.sv` | 50 | `if` |
| `link_fsm.sv` | 66 | `elsif` |
| `link_fsm.sv` | 69 | `if` |
| `link_fsm.sv` | 76 | `case` |
| `link_fsm.sv` | 78 | `elsif` |
| `link_fsm.sv` | 81 | `else` |
| `link_fsm.sv` | 81 | `if` |
| `link_fsm.sv` | 88 | `case` |
| `link_fsm.sv` | 88 | `case` |
| `die_a_system.sv` | 161 | `elsif` |
| `dma_offload_ctrl.sv` | 754 | `case` |
| `dma_offload_ctrl.sv` | 857 | `if` |
| `dma_offload_ctrl.sv` | 1154 | `case` |
| `aes128_iterative.sv` | 273 | `case` |
| `aes128_iterative.sv` | 289 | `case` |
| `die_b_system.sv` | 141 | `elsif` |

## Reviewed Toggle Hotspots

| File | Signal family | Missing points |
| --- | --- | ---: |
| `channel_model.sv` | `rev_data_pipe[][]` | 16 |
| `dma_offload_ctrl.sv` | `submit_dst_base_q[][]` | 9 |
| `channel_model.sv` | `lane_a_rx_data[]` | 8 |
| `channel_model.sv` | `lane_b_tx_data[]` | 8 |
| `dma_offload_ctrl.sv` | `retire_words_q[]` | 8 |
| `phy_behavioral.sv` | `adapter_tx_data[]` | 8 |
| `phy_behavioral.sv` | `channel_rx_data[]` | 8 |
| `dma_offload_ctrl.sv` | `comp_err_code_q[][]` | 6 |
| `dma_offload_ctrl.sv` | `comp_pop_words_q[]` | 6 |
| `dma_offload_ctrl.sv` | `comp_push_words_q[]` | 5 |
| `credit_mgr.sv` | `credit_available[]` | 4 |
| `credit_mgr.sv` | `credit_d[]` | 4 |
| `credit_mgr.sv` | `credit_q[]` | 4 |
| `dma_offload_ctrl.sv` | `active_len_words_q[]` | 4 |
| `dma_offload_ctrl.sv` | `recv_count_q[]` | 4 |
| `die_b_system.sv` | `cipher_fifo_count_q[]` | 4 |
| `dma_offload_ctrl.sv` | `staged_len_words_q[]` | 3 |
| `dma_offload_ctrl.sv` | `submit_src_base_q[][]` | 3 |
| `dma_offload_ctrl.sv` | `send_count_q[]` | 3 |
| `dma_offload_ctrl.sv` | `retire_err_code_q[]` | 3 |

## Reviewed Toggle Exclusions

| Rationale | Excluded points |
| --- | ---: |
| `credit_capacity_upper_bit` | 80 |
| `disabled_phy_probability_state` | 2 |
| `fixed_credit_initialization` | 40 |
| `hardwired_channel_fault_pipeline` | 10 |
| `long_horizon_diagnostic_counter` | 128 |
| `unit_credit_event_upper_bit` | 194 |

Release target status: **PASS** (line >= 95%, branch/expression >= 85%, reviewed toggle >= 90%).
Threshold enforcement for this invocation: **enabled**.

## Coverage By Source Group

| Source group | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `design_rtl` | 1991 | 2135 | 93.26% |
| `optional_collateral_rtl` | 121 | 131 | 92.37% |
| `checker_monitor` | 1294 | 1598 | 80.98% |
| `testbench` | 1975 | 3378 | 58.47% |

## Component Coverage

| Component | Hit | Total | Coverage |
| --- | ---: | ---: | ---: |
| `axi_lite_bridge` | 83 | 93 | 89.25% |
| `cdc_rdc_collateral` | 38 | 38 | 100.00% |
| `credit_manager` | 30 | 35 | 85.71% |
| `rv32_core` | NA | NA | NA |
| `apb_dma_csr_bridge` | NA | NA | NA |
| `rv32_rom_feeder` | NA | NA | NA |
| `soc_chiplet_rv32_top` | NA | NA | NA |

## Top Uncovered Design RTL Files

| File | Hit | Total | Missing | Coverage |
| --- | ---: | ---: | ---: | ---: |
| `dma_offload_ctrl.sv` | 766 | 834 | 68 | 91.85% |
| `die_a_system.sv` | 68 | 82 | 14 | 82.93% |
| `phy_behavioral.sv` | 79 | 91 | 12 | 86.81% |
| `die_b_system.sv` | 60 | 69 | 9 | 86.96% |
| `soc_die_a_top.sv` | 72 | 79 | 7 | 91.14% |
| `channel_model.sv` | 62 | 68 | 6 | 91.18% |
| `link_fsm.sv` | 57 | 62 | 5 | 91.94% |
| `soc_die_b_top.sv` | 44 | 49 | 5 | 89.80% |

- LCOV-style info: `chiplet_extension/reports/code_coverage.info`
- Annotated output: `chiplet_extension/build/code_coverage_annotated`
