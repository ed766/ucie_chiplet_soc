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

- Focused RV32/APB/ROM line coverage: **96.49%** (`rv32_core`: **96.24%**); branch/expression: **90.00%**

| Scenario | Result | RTL/ISS instructions | IRQs | Traps | MMIO R/W | DMA accept/complete |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `polling_dma` | PASS | 165 / 165 | 0 | 0 | 16 / 9 | 1 / 1 |
| `interrupt_dma` | PASS | 232 / 232 | 1 | 0 | 14 / 10 | 1 / 1 |
| `back_to_back` | PASS | 177 / 177 | 0 | 0 | 18 / 14 | 2 / 2 |
| `queue_full_recovery` | PASS | 990 / 990 | 0 | 0 | 384 / 43 | 6 / 7 |
| `timeout_handler` | PASS | 391 / 391 | 0 | 0 | 131 / 8 | 1 / 1 |
| `parity_error` | PASS | 165 / 165 | 0 | 0 | 3 / 9 | 1 / 1 |
| `invalid_source` | PASS | 134 / 134 | 0 | 0 | 3 / 7 | 1 / 1 |
| `sleep_resume` | PASS | 161 / 161 | 0 | 0 | 16 / 8 | 1 / 1 |
| `apb_wait_trap` | PASS | 299 / 299 | 0 | 3 | 2 / 2 | 0 / 0 |
| `reset_mid_wait` | PASS | 256 / 256 | 0 | 0 | 10 / 8 | 1 / 1 |
| `isa_matrix` | PASS | 837 / 837 | 0 | 11 | 1 / 2 | 0 / 0 |
| `operand_corner_matrix` | PASS | 156 / 156 | 0 | 0 | 0 / 1 | 0 / 0 |
| `csr_state_matrix` | PASS | 151 / 151 | 0 | 0 | 0 / 1 | 0 / 0 |
| `interrupt_before_after_retire` | PASS | 227 / 227 | 1 | 0 | 13 / 9 | 1 / 1 |
| `interrupt_during_apb_wait` | PASS | 217 / 217 | 1 | 0 | 8 / 9 | 1 / 1 |
| `interrupt_mask_pending_enable` | PASS | 229 / 229 | 1 | 0 | 13 / 10 | 1 / 1 |
| `apb_wait_depth_matrix` | PASS | 183 / 183 | 0 | 0 | 8 / 9 | 0 / 0 |
| `apb_reset_phase_matrix` | PASS | 163 / 163 | 0 | 0 | 10 / 8 | 1 / 1 |
| `apb_access_legality_matrix` | PASS | 356 / 356 | 0 | 4 | 1 / 2 | 0 / 0 |
| `dma_length_bank_matrix` | PASS | 478 / 478 | 0 | 0 | 153 / 25 | 4 / 4 |
| `dma_completion_pressure_irq` | PASS | 838 / 838 | 2 | 0 | 181 / 28 | 4 / 4 |
| `dma_tag_reuse_recovery` | PASS | 425 / 425 | 0 | 0 | 141 / 13 | 2 / 2 |
| `power_active_dma_matrix` | PASS | 237 / 237 | 1 | 0 | 1 / 9 | 1 / 1 |
| `power_completion_pending_matrix` | PASS | 228 / 228 | 1 | 0 | 1 / 9 | 1 / 1 |
| `c_initialized_data_sections` | PASS | 189 / 189 | 0 | 0 | 1 / 2 | 0 / 0 |
| `c_abi_stack_call_matrix` | PASS | 340 / 340 | 0 | 0 | 0 / 1 | 0 / 0 |
| `rv32_decode_legality_matrix` | PASS | 353 / 353 | 0 | 4 | 0 / 1 | 0 / 0 |
| `rv32_control_flow_boundary_matrix` | PASS | 275 / 275 | 0 | 2 | 0 / 1 | 0 / 0 |
| `rv32_sram_boundary_fault_matrix` | PASS | 246 / 246 | 0 | 2 | 0 / 1 | 0 / 0 |
| `csr_illegal_mask_alignment_matrix` | PASS | 201 / 201 | 0 | 1 | 0 / 1 | 0 / 0 |
| `irq_trap_priority_matrix` | PASS | 443 / 443 | 1 | 1 | 0 / 2 | 0 / 0 |
| `irq_level_mret_matrix` | PASS | 503 / 503 | 2 | 1 | 0 / 3 | 0 / 0 |
| `reset_irq_handler_matrix` | PASS | 686 / 686 | 2 | 0 | 0 / 2 | 0 / 0 |
| `apb_atomicity_wait_error_matrix` | PASS | 245 / 245 | 0 | 2 | 2 / 3 | 0 / 0 |
| `firmware_completion_mode_error_power_matrix` | PASS | 228 / 228 | 1 | 0 | 1 / 9 | 1 / 1 |
| `cpu_seed_00` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_01` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_02` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_03` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_04` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_05` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_06` | PASS | 554 / 554 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_07` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_08` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_09` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_10` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_11` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_12` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_13` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_14` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_15` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_16` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_17` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_18` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_19` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_20` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_21` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_22` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_23` | PASS | 555 / 555 | 0 | 1 | 0 / 1 | 0 / 0 |
| `cpu_seed_24` | PASS | 556 / 556 | 0 | 1 | 0 / 1 | 0 / 0 |
| `workload_seed_00` | PASS | 337 / 337 | 0 | 0 | 104 / 7 | 1 / 1 |
| `workload_seed_01` | PASS | 493 / 493 | 4 | 0 | 29 / 30 | 4 / 4 |
| `workload_seed_02` | PASS | 217 / 217 | 0 | 0 | 30 / 19 | 3 / 3 |
| `workload_seed_03` | PASS | 517 / 517 | 2 | 0 | 120 / 16 | 2 / 2 |
| `workload_seed_04` | PASS | 233 / 233 | 1 | 0 | 1 / 11 | 1 / 1 |
| `workload_seed_05` | PASS | 443 / 443 | 4 | 0 | 4 / 30 | 4 / 4 |
| `workload_seed_06` | PASS | 217 / 217 | 0 | 0 | 30 / 19 | 3 / 3 |
| `workload_seed_07` | PASS | 321 / 321 | 2 | 0 | 22 / 16 | 2 / 2 |
| `workload_seed_08` | PASS | 301 / 301 | 0 | 0 | 86 / 7 | 1 / 1 |
| `workload_seed_09` | PASS | 615 / 615 | 4 | 0 | 90 / 30 | 4 / 4 |
| `workload_seed_10` | PASS | 438 / 438 | 3 | 0 | 21 / 25 | 3 / 3 |
| `workload_seed_11` | PASS | 281 / 281 | 2 | 0 | 2 / 16 | 2 / 2 |
| `workload_seed_12` | PASS | 317 / 317 | 0 | 0 | 94 / 7 | 1 / 1 |
| `workload_seed_13` | PASS | 493 / 493 | 4 | 0 | 29 / 30 | 4 / 4 |
| `workload_seed_14` | PASS | 247 / 247 | 0 | 0 | 45 / 19 | 3 / 3 |
| `workload_seed_15` | PASS | 477 / 477 | 2 | 0 | 100 / 16 | 2 / 2 |
| `workload_seed_16` | PASS | 233 / 233 | 1 | 0 | 1 / 11 | 1 / 1 |
| `workload_seed_17` | PASS | 443 / 443 | 4 | 0 | 4 / 30 | 4 / 4 |
| `workload_seed_18` | PASS | 207 / 207 | 0 | 0 | 25 / 19 | 3 / 3 |
| `workload_seed_19` | PASS | 339 / 339 | 2 | 0 | 31 / 16 | 2 / 2 |
| `workload_seed_20` | PASS | 301 / 301 | 0 | 0 | 86 / 7 | 1 / 1 |
| `workload_seed_21` | PASS | 701 / 701 | 4 | 0 | 133 / 30 | 4 / 4 |
| `workload_seed_22` | PASS | 446 / 446 | 3 | 0 | 25 / 25 | 3 / 3 |
| `workload_seed_23` | PASS | 281 / 281 | 2 | 0 | 2 / 16 | 2 / 2 |
| `workload_seed_24` | PASS | 359 / 359 | 0 | 0 | 115 / 7 | 1 / 1 |

## Scope

The checker independently models GPRs, local memory, machine CSRs, PC flow, traps, interrupt state, access masks, and load/store merging. MMIO read values remain device observations; the checker independently validates their architectural effects while the existing DMA/AES memory model remains authoritative for device behavior. Detailed functional coverage, native Verilator code coverage, per-test contribution ranking, and performance evidence are reported separately. It is not Spike, Sail, or an official RISC-V compliance framework. This is behavioral pre-silicon evidence, not production firmware, FPGA/emulation, or RISC-V compliance certification.
