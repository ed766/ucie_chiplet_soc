# Compiled-C Firmware and ISS Co-Verification

This lane compiles freestanding RV32I/Zicsr C programs with the checksum-pinned GCC/binutils packages in `firmware_c/toolchain.lock.json`, executes them on the RTL core, and checks every normalized retirement record with a repository-local independent architectural ISS.

- Closure executions: **85 / 85**
- Named directed programs: **35 / 35**
- Seeded CPU streams: **25 / 25**
- Seeded firmware workloads: **25 / 25**
- Firmware/ISA coverage: **176 / 176**
- Firmware/outcome/power crosses: **88 / 88**
- Scenario-name-only coverage credit: **0 bins**
- Unexpected ISS mismatches: **0**

Evidence provenance is machine-readable in `chiplet_extension/reports/firmware_c_evidence_audit.csv`: 96 RVFI items, 20 APB transaction items, 60 firmware/device items, and 88 same-window crosses all meet expectation.

- Focused RV32/APB/ROM line coverage: **96.27%** (`rv32_core`: **96.00%**); branch/expression: **93.10%**

| Scenario | Result | RTL/ISS instructions | IRQs | Traps | MMIO R/W | DMA accept/complete |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `polling_dma` | PASS | 132 / 132 | 0 | 0 | 16 / 8 | 1 / 1 |
| `interrupt_dma` | PASS | 184 / 184 | 1 | 0 | 14 / 9 | 1 / 1 |
| `back_to_back` | PASS | 144 / 144 | 0 | 0 | 18 / 13 | 2 / 2 |
| `queue_full_recovery` | PASS | 957 / 957 | 0 | 0 | 384 / 42 | 6 / 7 |
| `timeout_handler` | PASS | 358 / 358 | 0 | 0 | 131 / 7 | 1 / 1 |
| `parity_error` | PASS | 132 / 132 | 0 | 0 | 3 / 8 | 1 / 1 |
| `invalid_source` | PASS | 101 / 101 | 0 | 0 | 3 / 6 | 1 / 1 |
| `sleep_resume` | PASS | 128 / 128 | 0 | 0 | 16 / 7 | 1 / 1 |
| `apb_wait_trap` | PASS | 233 / 233 | 0 | 3 | 2 / 1 | 0 / 0 |
| `reset_mid_wait` | PASS | 195 / 195 | 0 | 0 | 10 / 7 | 1 / 1 |
| `isa_matrix` | PASS | 683 / 683 | 0 | 11 | 1 / 1 | 0 / 0 |
| `operand_corner_matrix` | PASS | 120 / 120 | 0 | 0 | 0 / 0 | 0 / 0 |
| `csr_state_matrix` | PASS | 108 / 108 | 0 | 0 | 0 / 0 | 0 / 0 |
| `interrupt_before_after_retire` | PASS | 179 / 179 | 1 | 0 | 13 / 8 | 1 / 1 |
| `interrupt_during_apb_wait` | PASS | 169 / 169 | 1 | 0 | 8 / 8 | 1 / 1 |
| `interrupt_mask_pending_enable` | PASS | 181 / 181 | 1 | 0 | 13 / 9 | 1 / 1 |
| `apb_wait_depth_matrix` | PASS | 150 / 150 | 0 | 0 | 8 / 8 | 0 / 0 |
| `apb_reset_phase_matrix` | PASS | 130 / 130 | 0 | 0 | 10 / 7 | 1 / 1 |
| `apb_access_legality_matrix` | PASS | 279 / 279 | 0 | 4 | 1 / 1 | 0 / 0 |
| `dma_length_bank_matrix` | PASS | 445 / 445 | 0 | 0 | 153 / 24 | 4 / 4 |
| `dma_completion_pressure_irq` | PASS | 787 / 787 | 2 | 0 | 185 / 27 | 4 / 4 |
| `dma_tag_reuse_recovery` | PASS | 410 / 410 | 0 | 0 | 150 / 12 | 2 / 2 |
| `power_active_dma_matrix` | PASS | 189 / 189 | 1 | 0 | 1 / 8 | 1 / 1 |
| `power_completion_pending_matrix` | PASS | 180 / 180 | 1 | 0 | 1 / 8 | 1 / 1 |
| `c_initialized_data_sections` | PASS | 134 / 134 | 0 | 0 | 0 / 0 | 0 / 0 |
| `c_abi_stack_call_matrix` | PASS | 137 / 137 | 0 | 0 | 0 / 0 | 0 / 0 |
| `rv32_decode_legality_matrix` | PASS | 276 / 276 | 0 | 4 | 0 / 0 | 0 / 0 |
| `rv32_control_flow_boundary_matrix` | PASS | 220 / 220 | 0 | 2 | 0 / 0 | 0 / 0 |
| `rv32_sram_boundary_fault_matrix` | PASS | 237 / 237 | 0 | 3 | 0 / 0 | 0 / 0 |
| `csr_illegal_mask_alignment_matrix` | PASS | 157 / 157 | 0 | 1 | 0 / 0 | 0 / 0 |
| `irq_trap_priority_matrix` | PASS | 384 / 384 | 1 | 1 | 0 / 1 | 0 / 0 |
| `irq_level_mret_matrix` | PASS | 429 / 429 | 2 | 1 | 0 / 2 | 0 / 0 |
| `reset_irq_handler_matrix` | PASS | 610 / 610 | 2 | 0 | 0 / 1 | 0 / 0 |
| `apb_atomicity_wait_error_matrix` | PASS | 190 / 190 | 0 | 2 | 2 / 2 | 0 / 0 |
| `firmware_completion_mode_error_power_matrix` | PASS | 180 / 180 | 1 | 0 | 1 / 8 | 1 / 1 |
| `cpu_seed_00` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_01` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_02` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_03` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_04` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_05` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_06` | PASS | 510 / 510 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_07` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_08` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_09` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_10` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_11` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_12` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_13` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_14` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_15` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_16` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_17` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_18` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_19` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_20` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_21` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_22` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_23` | PASS | 511 / 511 | 0 | 1 | 0 / 0 | 0 / 0 |
| `cpu_seed_24` | PASS | 512 / 512 | 0 | 1 | 0 / 0 | 0 / 0 |
| `workload_seed_00` | PASS | 304 / 304 | 0 | 0 | 104 / 6 | 1 / 1 |
| `workload_seed_01` | PASS | 400 / 400 | 4 | 0 | 29 / 29 | 4 / 4 |
| `workload_seed_02` | PASS | 184 / 184 | 0 | 0 | 30 / 18 | 3 / 3 |
| `workload_seed_03` | PASS | 454 / 454 | 2 | 0 | 120 / 15 | 2 / 2 |
| `workload_seed_04` | PASS | 185 / 185 | 1 | 0 | 1 / 10 | 1 / 1 |
| `workload_seed_05` | PASS | 350 / 350 | 4 | 0 | 4 / 29 | 4 / 4 |
| `workload_seed_06` | PASS | 184 / 184 | 0 | 0 | 30 / 18 | 3 / 3 |
| `workload_seed_07` | PASS | 258 / 258 | 2 | 0 | 22 / 15 | 2 / 2 |
| `workload_seed_08` | PASS | 268 / 268 | 0 | 0 | 86 / 6 | 1 / 1 |
| `workload_seed_09` | PASS | 522 / 522 | 4 | 0 | 90 / 29 | 4 / 4 |
| `workload_seed_10` | PASS | 360 / 360 | 3 | 0 | 21 / 24 | 3 / 3 |
| `workload_seed_11` | PASS | 218 / 218 | 2 | 0 | 2 / 15 | 2 / 2 |
| `workload_seed_12` | PASS | 284 / 284 | 0 | 0 | 94 / 6 | 1 / 1 |
| `workload_seed_13` | PASS | 400 / 400 | 4 | 0 | 29 / 29 | 4 / 4 |
| `workload_seed_14` | PASS | 214 / 214 | 0 | 0 | 45 / 18 | 3 / 3 |
| `workload_seed_15` | PASS | 414 / 414 | 2 | 0 | 100 / 15 | 2 / 2 |
| `workload_seed_16` | PASS | 185 / 185 | 1 | 0 | 1 / 10 | 1 / 1 |
| `workload_seed_17` | PASS | 350 / 350 | 4 | 0 | 4 / 29 | 4 / 4 |
| `workload_seed_18` | PASS | 174 / 174 | 0 | 0 | 25 / 18 | 3 / 3 |
| `workload_seed_19` | PASS | 276 / 276 | 2 | 0 | 31 / 15 | 2 / 2 |
| `workload_seed_20` | PASS | 268 / 268 | 0 | 0 | 86 / 6 | 1 / 1 |
| `workload_seed_21` | PASS | 608 / 608 | 4 | 0 | 133 / 29 | 4 / 4 |
| `workload_seed_22` | PASS | 368 / 368 | 3 | 0 | 25 / 24 | 3 / 3 |
| `workload_seed_23` | PASS | 218 / 218 | 2 | 0 | 2 / 15 | 2 / 2 |
| `workload_seed_24` | PASS | 326 / 326 | 0 | 0 | 115 / 6 | 1 / 1 |

## Scope

The checker independently models GPRs, local memory, machine CSRs, PC flow, traps, interrupt state, access masks, and load/store merging. MMIO read values remain device observations; the checker independently validates their architectural effects while the existing DMA/AES memory model remains authoritative for device behavior. Detailed functional coverage, native Verilator code coverage, per-test contribution ranking, and performance evidence are reported separately. It is not Spike, Sail, or an official RISC-V compliance framework. This is behavioral pre-silicon evidence, not production firmware, FPGA/emulation, or RISC-V compliance certification.
