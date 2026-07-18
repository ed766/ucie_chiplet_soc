# Compiled-C Firmware and ISS Co-Verification

This lane compiles freestanding RV32I/Zicsr C programs with the checksum-pinned GCC/binutils packages in `firmware_c/toolchain.lock.json`, executes them on the RTL core, and checks every normalized retirement record with a repository-local independent architectural ISS.

- Closure executions: **85 / 85**
- Named directed programs: **35 / 35**
- Seeded CPU streams: **25 / 25**
- Seeded firmware workloads: **25 / 25**
- Firmware/ISA coverage: **178 / 178**
- Firmware/outcome/power crosses: **94 / 94**
- Scenario-name-only coverage credit: **0 bins**
- Unexpected ISS mismatches: **0**

Evidence provenance is machine-readable in `chiplet_extension/reports/firmware_c_evidence_audit.csv`: 96 RVFI items, 20 APB transaction items, 60 firmware/device items, and 88 same-window crosses all meet expectation.

- Focused RV32/APB/ROM line coverage: **96.90%** (`rv32_core`: **96.69%**); branch/expression: **91.18%**

| Scenario | Result | RTL/ISS instructions | IRQs | Traps | MMIO R/W | DMA accept/complete |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `polling_dma` | PASS | 153 / 153 | 0 | 0 | 16 / 9 | 1 / 1 |
| `interrupt_dma` | PASS | 209 / 209 | 1 | 0 | 14 / 10 | 1 / 1 |
| `back_to_back` | PASS | 165 / 165 | 0 | 0 | 18 / 14 | 2 / 2 |
| `queue_full_recovery` | PASS | 978 / 978 | 0 | 0 | 384 / 43 | 6 / 7 |
| `timeout_handler` | PASS | 379 / 379 | 0 | 0 | 131 / 8 | 1 / 1 |
| `parity_error` | PASS | 153 / 153 | 0 | 0 | 3 / 9 | 1 / 1 |
| `invalid_source` | PASS | 122 / 122 | 0 | 0 | 3 / 7 | 1 / 1 |
| `sleep_resume` | PASS | 149 / 149 | 0 | 0 | 16 / 8 | 1 / 1 |
| `apb_wait_trap` | PASS | 254 / 254 | 0 | 3 | 2 / 2 | 0 / 0 |
| `reset_mid_wait` | PASS | 232 / 232 | 0 | 0 | 10 / 8 | 1 / 1 |
| `isa_matrix` | PASS | 704 / 704 | 0 | 11 | 1 / 2 | 0 / 0 |
| `operand_corner_matrix` | PASS | 144 / 144 | 0 | 0 | 0 / 1 | 0 / 0 |
| `csr_state_matrix` | PASS | 139 / 139 | 0 | 0 | 0 / 1 | 0 / 0 |
| `interrupt_before_after_retire` | PASS | 204 / 204 | 1 | 0 | 13 / 9 | 1 / 1 |
| `interrupt_during_apb_wait` | PASS | 194 / 194 | 1 | 0 | 8 / 9 | 1 / 1 |
| `interrupt_mask_pending_enable` | PASS | 206 / 206 | 1 | 0 | 13 / 10 | 1 / 1 |
| `apb_wait_depth_matrix` | PASS | 171 / 171 | 0 | 0 | 8 / 9 | 0 / 0 |
| `apb_reset_phase_matrix` | PASS | 151 / 151 | 0 | 0 | 10 / 8 | 1 / 1 |
| `apb_access_legality_matrix` | PASS | 300 / 300 | 0 | 4 | 1 / 2 | 0 / 0 |
| `dma_length_bank_matrix` | PASS | 466 / 466 | 0 | 0 | 153 / 25 | 4 / 4 |
| `dma_completion_pressure_irq` | PASS | 515 / 515 | 1 | 0 | 101 / 27 | 4 / 4 |
| `dma_tag_reuse_recovery` | PASS | 413 / 413 | 0 | 0 | 141 / 13 | 2 / 2 |
| `power_active_dma_matrix` | PASS | 214 / 214 | 1 | 0 | 1 / 9 | 1 / 1 |
| `power_completion_pending_matrix` | PASS | 205 / 205 | 1 | 0 | 1 / 9 | 1 / 1 |
| `c_initialized_data_sections` | PASS | 177 / 177 | 0 | 0 | 1 / 2 | 0 / 0 |
| `c_abi_stack_call_matrix` | PASS | 328 / 328 | 0 | 0 | 0 / 1 | 0 / 0 |
| `rv32_decode_legality_matrix` | PASS | 297 / 297 | 0 | 4 | 0 / 1 | 0 / 0 |
| `rv32_control_flow_boundary_matrix` | PASS | 241 / 241 | 0 | 2 | 0 / 1 | 0 / 0 |
| `rv32_sram_boundary_fault_matrix` | PASS | 212 / 212 | 0 | 2 | 0 / 1 | 0 / 0 |
| `csr_illegal_mask_alignment_matrix` | PASS | 178 / 178 | 0 | 1 | 0 / 1 | 0 / 0 |
| `irq_trap_priority_matrix` | PASS | 409 / 409 | 1 | 1 | 0 / 2 | 0 / 0 |
| `irq_level_mret_matrix` | PASS | 458 / 458 | 2 | 1 | 0 / 3 | 0 / 0 |
| `reset_irq_handler_matrix` | PASS | 651 / 651 | 2 | 0 | 0 / 2 | 0 / 0 |
| `apb_atomicity_wait_error_matrix` | PASS | 211 / 211 | 0 | 2 | 2 / 3 | 0 / 0 |
| `firmware_completion_mode_error_power_matrix` | PASS | 205 / 205 | 1 | 0 | 1 / 9 | 1 / 1 |
| `cpu_seed_00` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_01` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_02` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_03` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_04` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_05` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_06` | PASS | 531 / 531 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_07` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_08` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_09` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_10` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_11` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_12` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_13` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_14` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_15` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_16` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_17` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_18` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_19` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_20` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_21` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_22` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_23` | PASS | 532 / 532 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_24` | PASS | 533 / 533 | 0 | 1 | 0 / 1 | 0 / 0 |
| `workload_seed_00` | PASS | 325 / 325 | 0 | 0 | 104 / 7 | 1 / 1 |
| `workload_seed_01` | PASS | 437 / 437 | 4 | 0 | 29 / 30 | 4 / 4 |
| `workload_seed_02` | PASS | 205 / 205 | 0 | 0 | 30 / 19 | 3 / 3 |
| `workload_seed_03` | PASS | 483 / 483 | 2 | 0 | 120 / 16 | 2 / 2 |
| `workload_seed_04` | PASS | 210 / 210 | 1 | 0 | 1 / 11 | 1 / 1 |
| `workload_seed_05` | PASS | 387 / 387 | 4 | 0 | 4 / 30 | 4 / 4 |
| `workload_seed_06` | PASS | 205 / 205 | 0 | 0 | 30 / 19 | 3 / 3 |
| `workload_seed_07` | PASS | 287 / 287 | 2 | 0 | 22 / 16 | 2 / 2 |
| `workload_seed_08` | PASS | 289 / 289 | 0 | 0 | 86 / 7 | 1 / 1 |
| `workload_seed_09` | PASS | 559 / 559 | 4 | 0 | 90 / 30 | 4 / 4 |
| `workload_seed_10` | PASS | 393 / 393 | 3 | 0 | 21 / 25 | 3 / 3 |
| `workload_seed_11` | PASS | 247 / 247 | 2 | 0 | 2 / 16 | 2 / 2 |
| `workload_seed_12` | PASS | 305 / 305 | 0 | 0 | 94 / 7 | 1 / 1 |
| `workload_seed_13` | PASS | 437 / 437 | 4 | 0 | 29 / 30 | 4 / 4 |
| `workload_seed_14` | PASS | 235 / 235 | 0 | 0 | 45 / 19 | 3 / 3 |
| `workload_seed_15` | PASS | 443 / 443 | 2 | 0 | 100 / 16 | 2 / 2 |
| `workload_seed_16` | PASS | 210 / 210 | 1 | 0 | 1 / 11 | 1 / 1 |
| `workload_seed_17` | PASS | 387 / 387 | 4 | 0 | 4 / 30 | 4 / 4 |
| `workload_seed_18` | PASS | 195 / 195 | 0 | 0 | 25 / 19 | 3 / 3 |
| `workload_seed_19` | PASS | 305 / 305 | 2 | 0 | 31 / 16 | 2 / 2 |
| `workload_seed_20` | PASS | 289 / 289 | 0 | 0 | 86 / 7 | 1 / 1 |
| `workload_seed_21` | PASS | 645 / 645 | 4 | 0 | 133 / 30 | 4 / 4 |
| `workload_seed_22` | PASS | 401 / 401 | 3 | 0 | 25 / 25 | 3 / 3 |
| `workload_seed_23` | PASS | 247 / 247 | 2 | 0 | 2 / 16 | 2 / 2 |
| `workload_seed_24` | PASS | 347 / 347 | 0 | 0 | 115 / 7 | 1 / 1 |

## Scope

The checker independently models GPRs, local memory, machine CSRs, PC flow, traps, interrupt state, access masks, and load/store merging. MMIO read values remain device observations; the checker independently validates their architectural effects while the existing DMA/AES memory model remains authoritative for device behavior. Detailed functional coverage, native Verilator code coverage, per-test contribution ranking, and performance evidence are reported separately. It is not Spike, Sail, or an official RISC-V compliance framework. This is behavioral pre-silicon evidence, not production firmware, FPGA/emulation, or RISC-V compliance certification.
