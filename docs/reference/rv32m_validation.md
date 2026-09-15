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
| Directed arithmetic and integration | `24 / 24` | Eight opcodes, architectural corner cases, aliases, `x0`, reset, interrupt ordering, and disabled-extension behavior |
| Operand-class coverage | `48 / 48` | Eight opcodes crossed with six mutually exclusive operand classes |
| Seeded arithmetic streams | `100 / 100` | Deterministic mixed-operation streams checked against an independent Python arithmetic model |
| Compiler matrix | `36 / 36` | Six kernels at `-O0`, `-O2`, and `-Os` for both RV32I and RV32IM |
| Formal groups | `2 / 2` | Solver-backed bounded protocol safety and opcode reachability covers |
| RTL mutations | `8 / 8` | Product, signedness, quotient, remainder, exceptional-case, retirement, and reset defects |

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

