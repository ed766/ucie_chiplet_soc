# RV32 Architectural Validation Dashboard

This dashboard separates independent architectural oracles instead of treating one
repository-local checker as proof of correctness. Results apply to the documented
RV32I/Zicsr machine-mode subset; they are not RISC-V certification.

## Release Evidence

| Evidence lane | Current result | What it independently checks | Canonical report |
| --- | ---: | --- | --- |
| Pinned dependency integrity | `7 PASS / 0 SKIP / 0 FAIL` | Git revisions and archive SHA-256 values | `chiplet_extension/reports/rv32_external_tool_status.csv` |
| Spike CPU differential | `12 PASS / 0 SKIP / 0 FAIL` | PC/instruction, register write, memory address/mask, and store-data comparison across ALU, ABI, CSR, memory-width, dependency, control-flow, and optimizer cases | `chiplet_extension/reports/rv32_external_iss_summary.csv` |
| ACT4/Sail RTL execution | `45 PASS / 0 SKIP / 0 FAIL` | Self-checking generated RV32I/Zicsr architectural ELFs executed on RTL | `chiplet_extension/reports/rv32_act_summary.csv` |
| Standard/custom RVFI formal | `3 PASS / 0 SKIP / 0 FAIL` | Instruction/register/PC ordering plus bounded CSR, trap, APB, interrupt, and `mscratch` properties | `chiplet_extension/reports/rv32_formal_summary.csv` |
| External-oracle mutation sensitivity | `5 PASS / 0 SKIP / 0 FAIL` | A real injected RTL defect is detected by each oracle family | `chiplet_extension/reports/rv32_external_mutation_matrix.csv` |
| Privileged GCC/ISS scenarios | `8 PASS / 0 SKIP / 0 FAIL` | `misa`, `mtval`, direct/vectored `mtvec`, interrupt causes, and `MRET` state restoration | `chiplet_extension/reports/privileged_arch_summary.csv` |
| Privileged functional/cross evidence | `32 / 32` points; `16 / 16` crosses | Same-window cause/value/vector/source/return interactions | `chiplet_extension/reports/privileged_arch_coverage_summary.csv` |

## Behavior-to-Oracle Matrix

| Architectural behavior | Local ISS | Spike | ACT4/Sail | SVA / formal |
| --- | :---: | :---: | :---: | :---: |
| RV32I ALU, branches, loads/stores | Full retirement replay | CPU-only differential | Generated architectural tests | Standard RVFI checks |
| Compiler ABI and optimizer behavior | GPR/SRAM/signature replay | 12-program architectural-effect matrix | Not an ABI suite | Retirement/order invariants |
| Zicsr including `mscratch` | CSR state transition model | CPU-only CSR program | Six Zicsr form suites | Directed SVA plus bounded next-state property |
| Traps, `MRET`, external/timer IRQs | Precise machine-state model | CPU-only subset | Applicable architectural tests | Custom bounded properties |
| `misa`, `mtval`, direct/vectored `mtvec` | Full CSR/trap replay | Project-specific vector-handler programs out of scope | Applicable Zicsr tests | Named SVA plus custom bounded properties |
| APB, DMA, power, timer MMIO | Device-input and side-effect checks | Out of scope | Out of scope | APB/retirement and power-order assertions |

## Mutation Sensitivity

| Oracle | RTL mutation | Expected symptom | Result |
| --- | --- | --- | ---: |
| `repository_local_iss_and_sva` | `RV32_BUG_MSCRATCH_WRITE_DROP` | architectural_state_or_assertion_mismatch | `PASS` |
| `Spike` | `RV32_BUG_ALU_RESULT` | architectural_register_or_control_flow_divergence | `PASS` |
| `Spike` | `RV32_BUG_MSTATUS_MPP_ZERO` | machine_mode_mstatus_register_divergence | `PASS` |
| `ACT4/Sail` | `RV32_BUG_MSCRATCH_WRITE_DROP` | self_checking_Zicsr_mailbox_failure | `PASS` |
| `SymbiYosys_custom_RVFI` | `RV32_BUG_MSCRATCH_WRITE_DROP` | bounded_counterexample | `PASS` |

The ACT4 report distinguishes dependency/generation failure, host timeout, RTL mailbox
timeout, and self-checking mailbox failure. Failure rows include the last retired PC,
mailbox value, expected result, observed result, and RVFI trace path; register-specific
fields are explicitly `NA` when ACT's generated mailbox does not expose them.

The Spike lane uses pure CPU programs and compares all logged architectural register and
memory effects. The only permitted suffix is the bounded result-mailbox termination sequence:
Spike faults on the project-specific mailbox address while RTL accepts it and ends the test.
Mutation artifacts use distinct paths and cannot overwrite nominal release traces.

## Third-Party Findings Closed

| Finding | Exposed by | Resolution | Regression evidence |
| --- | --- | --- | --- |
| `mscratch` was absent from the original local ISS/coverage model | ACT4 Zicsr tests | Added RTL trace state, local-ISS semantics, all six CSR forms, assertions, formal next-state checks, and a drop-write mutation | ACT4 `45 / 45`; `RV32_BUG_MSCRATCH_WRITE_DROP` detected |
| Machine-only `mstatus.MPP` read as zero instead of Machine mode | Architectural-effect-aware Spike comparison | Made MPP WARL-fixed to `2'b11`, updated the ISS and checks, and added a dedicated formal/SVA invariant and RTL mutation | Spike `12 / 12`; `RV32_BUG_MSTATUS_MPP_ZERO` detected |
| Spike compared only PC/instruction prefixes and mutation runs overwrote nominal traces | External-evidence audit | Added register, memory address/mask, and store-data checks; pure-CPU programs; bounded terminal relation; isolated artifact suffixes | External mutation matrix `5 / 5` |
| Nonzero synchronous `mtval` was overwritten in the RVFI event by generic trace initialization | Privileged GCC scenario and named trap assertion | Reapplied the architecturally computed trap value after RVFI base initialization | Privileged scenarios `8 / 8`; coverage `32 / 32`; crosses `16 / 16` |
| CSRRS/CSRRC write intent incorrectly depended on runtime source value instead of encoded source index | SymbiYosys custom property | Added architectural write-intent decoding, so nonzero `rs1` targeting read-only `misa` traps even when the register contains zero | Custom formal passes at its documented bound; privileged scenarios remain `8 / 8` |

## Reproduce

```bash
make -C chiplet_extension rv32-external-tools-install
make -C chiplet_extension rv32-external-iss-check
make -C chiplet_extension rv32-act-check
make -C chiplet_extension rv32-formal-check
make -C chiplet_extension rv32-external-mutation-check
make -C chiplet_extension privileged-arch-check
```

Release validation uses `--require`; missing, skipped, revision-mismatched, or
checksum-mismatched external dependencies fail the release rather than producing a
nominal success.
