# Optional RV32M Validation

The RV32 core supports the complete integer multiply/divide extension when
`ENABLE_M=1`. The released default remains RV32I/Zicsr (`ENABLE_M=0`), and M
encodings trap as illegal instructions in that configuration.

The implementation uses a separate iterative `rv32_muldiv` block. It accepts
one operation, captures both operands, performs 32 arithmetic iterations, and
holds its result until the core consumes it. Younger instructions, APB traffic,
and interrupts cannot pass the active arithmetic instruction. Reset cancels an
unfinished operation without a later response or retirement.

## Executable Evidence

| Lane | Result | Scope |
| --- | ---: | --- |
| Directed arithmetic unit | `24 / 24` | Named unit cases; not a complete core/subsystem matrix |
| Operand-class coverage | `48 / 48` | Eight opcodes crossed with six mutually exclusive operand classes |
| Seeded arithmetic unit vectors | `100 / 100` | Arithmetic-unit vectors, not CPU instruction streams |
| Core boundary executions | `312 / 312` | Disabled legality, aliases, dependencies, IRQs, resets, APB waits, and precise faults with ISS replay |
| Compiler matrix | `36 / 36` | Six kernels at `-O0`, `-O2`, and `-Os` for both RV32I and RV32IM |
| Formal groups | See [canonical report](../../chiplet_extension/reports/rv32m_formal_summary.csv) | Real-unit depth-84 safety/covers; separate abstract-unit core-control checks |
| RTL mutations | `8 / 8` | Passing nominal control, successful build, activation marker, and exact intended failure required |

The compiler matrix verifies the instructions that actually retire, rather
than inferring coverage from ELF disassembly. RV32IM executions retired M
instructions; matching RV32I executions used checked freestanding arithmetic
helpers and retired no M instructions.

## Architectural Boundaries

- Signed division truncates toward zero and remainder follows the dividend.
- Divide-by-zero and signed-minimum divided by `-1` follow the RV32M rules.
- `misa.M` is exposed only when the complete extension is enabled.
- M operations generate no MMIO transactions and retire exactly once.
- The formal result is bounded safety evidence, not exhaustive full-width
  arithmetic equivalence or RISC-V certification.

Reproduce the lane with:

```bash
make -C chiplet_extension rv32m-release-check
```

## Core Boundary Matrix

[Executed rows](../../chiplet_extension/reports/rv32m_boundary_summary.csv) include
source/simulator identity, trace hash, stimulus-reached status, and retirement
witnesses identified by epoch/order/cycle.

- Eight disabled-opcode cases: cause 2, no GPR/memory/APB side effects.
- 32 alias cases: independent destination, `rd=rs1`, `rd=rs2`, and `rd=x0`,
  followed by dependent back-to-back M instructions.
- 48 event-targeted resets: before dispatch, early/middle/final iteration,
  finalization, and response availability; reboot into another M instruction.
- 192 IRQ cases: eight opcodes, external/timer/both sources, four arrival phases,
  masked/enabled state, exact `mepc`, handler M execution, and `MRET` restoration.
- 24 APB cases: wait buckets 0/1/4, load to M to store, correct data, exact
  transfer count, and no retirement while waiting.
- Eight M-generated addresses: first/last MMIO word, upper-word address,
  private-memory boundary, misalignment, reserved width, and slave error.
  These use a core APB slave, **not a downstream AXI lane scoreboard**.

IRQ/reset phase checks inspect actual busy/result/iteration state. Plusargs
alone cannot satisfy a scenario. Each case has one independent construction;
this does not establish two-test robustness for every subsystem predicate.

The counter checker found a real defect: synchronous traps incremented
`minstret`. The core now excludes both trap and interrupt pseudo-events.
This matrix checks counter increments without CSR writes; rollover and write
precedence remain in the timer/counter lane.

## Checker and Mutation Qualification

The ISS independently establishes legality: enabled M instructions cannot
spuriously trap and disabled M instructions cannot retire normally. Self-tests
exercise both defects for all eight opcodes, `x0`, and memory-effect suppression.
Word-only MMIO restrictions are distinct from instruction encoding legality.
CSRRS/CSRRC legality also uses the encoded source register, not its runtime
value: a nonzero source register containing zero still constitutes write intent.
Interrupt checking independently requires global and per-source enables and
applies priority only among enabled pending sources, rather than trusting the
observed interrupt event.

Mutation qualification rejects compile errors, generic timeouts, missing
activation, unrelated assertions, and failure without the intended diagnostic.

## Formal Scope

Real-unit depth-84 safety permits recurring requests, arbitrary operands,
response readiness, and mid-operation resets. It checks request/response
ownership, bounded completion, operand/opcode capture, stable response, and
reset cancellation. Covers reach all opcode responses, two completed operations,
and cancellation followed by a response. Only cover stimulus fixes operands to
zero/one; safety operands remain arbitrary.

The separate depth-50 core-control harness instantiates the actual core with an
arithmetic-contract abstraction: one response per request, latency 1-36, stable
arbitrary result, and reset cancellation. It checks instruction/PC capture,
consumption-before-retirement, and no APB/memory effects. Its instruction stream
uses M with `x0` operands/destination and IRQ inputs low. It does not prove
arithmetic equivalence, aliases, or interrupts; executable lanes check those.

## Code Coverage Boundaries

[Raw native counts](../../chiplet_extension/reports/rv32m_boundary_code_coverage.csv)
and [holes](../../chiplet_extension/reports/rv32m_boundary_coverage_holes.csv) keep
enabled/disabled configurations separate with **zero exclusions**. The enabled
unit combines core matrix and nominal unit coverage. Defensive opcode/state
defaults remain visible in raw line counts, rather than being artificially hit.

This focused matrix intentionally does not execute every non-M ISA path, so its
whole-core percentages do not replace GCC coverage. Conversely, GCC focused
coverage excluding `rv32_muldiv` is not complete RV32IM coverage. No denominator
inflates the canonical chiplet `60/60` model.

## Remaining Subsystem Closure

This core matrix does **not** close systematic M-phase crosses against live DMA
completion-full pressure, configuration references, delayed final AXI write
responses, retention restore, or concurrent AES/INT8 numerical checking.
The accelerator repository now provides the separate `compute-live-m-check`
lane: eight-opcode crosses against active DMA, concurrent AES/INT8, actual
chiplet SLEEP/resume, and completion-FIFO-full retirement pressure, plus a
precise device-IRQ boundary. It uses independently replayed firmware traces,
numerical output checking, and event IDs, not the core matrix as a substitute.
The protected-offload core/unit/feeder snapshot is imported byte-for-byte from
an immutable authoritative commit, including upstream verification hooks.
This sampled live lane does not close every operand or timing permutation,
configuration-reference phase, reset-with-both-services, or retention detail.

Remaining predicates are M busy/result/retired against DMA queued/active/
retirement-stalled/unread-completion phases; IRQ persistence and ordered tags;
sleep restore before firmware observation; independently validated AES/INT8
overlap; and actual AXI lane/error side effects. Each requires trace-window
provenance and intended mutation sensitivity, not scenario-name inference.

Additional focused commands:

```bash
make -C chiplet_extension rv32m-checker-selftest
make -C chiplet_extension rv32m-boundary-check
make -C chiplet_extension rv32m-code-coverage
make -C chiplet_extension rv32-external-iss-check
make -C chiplet_extension rv32-act-m-check
```

## Supplemental Stateful Core Control

`make -C chiplet_extension rv32m-stateful-formal` checks real core control with arbitrary instruction issue, nonzero/aliased GPR indices, external/timer interrupt inputs, repeated operations, and reset after initialization. The muldiv result is an assume-guarantee contract abstraction. Results are in `chiplet_extension/reports/rv32m_stateful_formal.csv`; depth-50 bounded safety is not unbounded proof or 32-bit arithmetic equivalence. Covers reach M retirement, nonzero/aliased destinations, external and timer interrupt entry, and MRET. Cover reachability does not prove correctness of every IRQ/M ordering combination.
