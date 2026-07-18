# RV32 Architectural Validation Dashboard

This dashboard separates independent architectural oracles instead of treating one
repository-local checker as proof of correctness. Results apply to the documented
RV32I/Zicsr machine-mode subset; they are not RISC-V certification.

## Release Evidence

| Evidence lane | Current result | What it independently checks | Canonical report |
| --- | ---: | --- | --- |
| Pinned dependency integrity | `7 PASS / 0 SKIP / 0 FAIL` | Git revisions and archive SHA-256 values | `chiplet_extension/reports/rv32_external_tool_status.csv` |
| Spike CPU differential | `12 PASS / 0 SKIP / 0 FAIL` | PC/instruction retirement prefix across ALU, ABI, data, CSR, control-flow, and optimizer variants | `chiplet_extension/reports/rv32_external_iss_summary.csv` |
| ACT4/Sail RTL execution | `45 PASS / 0 SKIP / 0 FAIL` | Self-checking generated RV32I/Zicsr architectural ELFs executed on RTL | `chiplet_extension/reports/rv32_act_summary.csv` |
| Standard/custom RVFI formal | `3 PASS / 0 SKIP / 0 FAIL` | Instruction/register/PC ordering plus bounded CSR, trap, APB, interrupt, and `mscratch` properties | `chiplet_extension/reports/rv32_formal_summary.csv` |
| External-oracle mutation sensitivity | `4 PASS / 0 SKIP / 0 FAIL` | A real injected RTL defect is detected by each oracle family | `chiplet_extension/reports/rv32_external_mutation_matrix.csv` |

## Behavior-to-Oracle Matrix

| Architectural behavior | Local ISS | Spike | ACT4/Sail | SVA / formal |
| --- | :---: | :---: | :---: | :---: |
| RV32I ALU, branches, loads/stores | Full retirement replay | CPU-only differential | Generated architectural tests | Standard RVFI checks |
| Compiler ABI and optimizer behavior | GPR/SRAM/signature replay | 12-program optimizer/ABI matrix | Not an ABI suite | Retirement/order invariants |
| Zicsr including `mscratch` | CSR state transition model | CPU-only CSR program | Six Zicsr form suites | Directed SVA plus bounded next-state property |
| Traps, `MRET`, external/timer IRQs | Precise machine-state model | CPU-only subset | Applicable architectural tests | Custom bounded properties |
| APB, DMA, power, timer MMIO | Device-input and side-effect checks | Out of scope | Out of scope | APB/retirement and power-order assertions |

## Mutation Sensitivity

| Oracle | RTL mutation | Expected symptom | Result |
| --- | --- | --- | ---: |
| `repository_local_iss_and_sva` | `RV32_BUG_MSCRATCH_WRITE_DROP` | architectural_state_or_assertion_mismatch | `PASS` |
| `Spike` | `RV32_BUG_ALU_RESULT` | PC/instruction_stream_divergence | `PASS` |
| `ACT4/Sail` | `RV32_BUG_MSCRATCH_WRITE_DROP` | self_checking_Zicsr_mailbox_failure | `PASS` |
| `SymbiYosys_custom_RVFI` | `RV32_BUG_MSCRATCH_WRITE_DROP` | bounded_counterexample | `PASS` |

The ACT4 report distinguishes dependency/generation failure, host timeout, RTL mailbox
timeout, and self-checking mailbox failure. Failure rows include the last retired PC,
mailbox value, expected result, observed result, and RVFI trace path; register-specific
fields are explicitly `NA` when ACT's generated mailbox does not expose them.

## Reproduce

```bash
make -C chiplet_extension rv32-external-tools-install
make -C chiplet_extension rv32-external-iss-check
make -C chiplet_extension rv32-act-check
make -C chiplet_extension rv32-formal-check
make -C chiplet_extension rv32-external-mutation-check
```

Release validation uses `--require`; missing, skipped, revision-mismatched, or
checksum-mismatched external dependencies fail the release rather than producing a
nominal success.
