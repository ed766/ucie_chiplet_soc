#!/usr/bin/env python3
"""Independent RV32I/Zicsr architectural checker for normalized RVFI traces."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path


def u32(value: int) -> int:
    return value & 0xFFFF_FFFF


def signed(value: int, bits: int = 32) -> int:
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def sext(value: int, bits: int) -> int:
    return u32(signed(value, bits))


def field(value: int, high: int, low: int) -> int:
    return (value >> low) & ((1 << (high - low + 1)) - 1)


def parse_hex(value: str) -> int:
    cleaned = value.strip().lower().replace("x", "0").replace("z", "0")
    return int(cleaned or "0", 16)


@dataclass
class CheckResult:
    instructions: int
    traps: int
    interrupts: int
    mismatches: list[str]


class RV32ISS:
    def __init__(self, instruction_manifest: Path | None = None,
                 data_image: Path | None = None) -> None:
        self.regs = [0] * 32
        self.memory: dict[int, int] = {}
        self.previous_order: int | None = None
        self.previous_epoch: int | None = None
        self.expected_order = 0
        self.expected_pc = 0
        self.instructions = 0
        self.traps = 0
        self.interrupts = 0
        self.mismatches: list[str] = []
        self.csrs = {0x300: 0, 0x304: 0, 0x305: 0x300, 0x341: 0, 0x342: 0}
        self.instructions_by_pc: dict[int, int] = {}
        self.initial_memory = self.load_data_image(data_image)
        self.memory.update(self.initial_memory)
        if instruction_manifest and instruction_manifest.exists():
            with instruction_manifest.open(newline="") as handle:
                for row in csv.DictReader(handle):
                    self.instructions_by_pc[parse_hex(row["pc"])] = parse_hex(row["insn"])

    @staticmethod
    def load_data_image(path: Path | None) -> dict[int, int]:
        memory: dict[int, int] = {}
        if not path or not path.exists():
            return memory
        word_index = 0
        for token in path.read_text().split():
            if token.startswith("@"): word_index = int(token[1:], 16)
            else:
                memory[word_index * 4] = int(token, 16)
                word_index += 1
        return memory

    def mismatch(self, order: int, message: str) -> None:
        if len(self.mismatches) < 20:
            self.mismatches.append(f"order {order}: {message}")

    def reset_epoch(self) -> None:
        self.regs = [0] * 32
        self.memory = dict(self.initial_memory)
        self.csrs = {0x300: 0, 0x304: 0, 0x305: 0x300, 0x341: 0, 0x342: 0}
        self.expected_order = 0
        self.expected_pc = 0

    def check_csr_snapshot(self, order: int, row: dict[str, str], *, trap_override: bool = False) -> None:
        observed = {
            0x300: parse_hex(row["mstatus"]), 0x304: parse_hex(row["mie"]),
            0x305: parse_hex(row["mtvec"]), 0x341: parse_hex(row["mepc"]),
            0x342: parse_hex(row["mcause"]),
        }
        for csr, value in observed.items():
            if trap_override and csr in (0x341, 0x342):
                continue
            if value != self.csrs[csr]:
                self.mismatch(order, f"CSR 0x{csr:03x}=0x{value:08x}, expected 0x{self.csrs[csr]:08x}")

    def check_row(self, row: dict[str, str]) -> None:
        order = int(row["order"])
        epoch = int(row.get("epoch", "0"))
        if self.previous_epoch is not None and epoch != self.previous_epoch:
            self.reset_epoch()
        elif self.previous_order is not None and order < self.previous_order:
            self.reset_epoch()
        if order != self.expected_order:
            self.mismatch(order, f"retirement order {order}, expected {self.expected_order}")
            self.expected_order = order
        self.previous_order = order
        self.previous_epoch = epoch
        insn = parse_hex(row["insn"])
        pc = parse_hex(row["pc_rdata"])
        observed_next_pc = parse_hex(row["pc_wdata"])
        trap = int(row["trap"])
        intr = int(row["intr"])
        rs1 = int(row["rs1_addr"])
        rs2 = int(row["rs2_addr"])
        observed_rs1 = parse_hex(row["rs1_rdata"])
        observed_rs2 = parse_hex(row["rs2_rdata"])
        observed_rd = int(row["rd_addr"])
        observed_rd_value = parse_hex(row["rd_wdata"])
        mem_address = parse_hex(row["mem_addr"])
        rmask = parse_hex(row["mem_rmask"])
        wmask = parse_hex(row["mem_wmask"])
        mem_rdata = parse_hex(row["mem_rdata"])
        mem_wdata = parse_hex(row["mem_wdata"])

        if pc != self.expected_pc:
            self.mismatch(order, f"current PC 0x{pc:08x}, expected 0x{self.expected_pc:08x}")
        if self.instructions_by_pc and not intr:
            expected_insn = self.instructions_by_pc.get(pc)
            if expected_insn is None:
                self.mismatch(order, f"PC 0x{pc:08x} is outside the instruction manifest")
            elif insn != expected_insn:
                self.mismatch(order, f"instruction 0x{insn:08x}, image has 0x{expected_insn:08x}")

        self.check_csr_snapshot(order, row, trap_override=bool(trap or intr))

        if observed_rs1 != self.regs[rs1]:
            self.mismatch(order, f"rs1 x{rs1}=0x{observed_rs1:08x}, expected 0x{self.regs[rs1]:08x}")
        if observed_rs2 != self.regs[rs2]:
            self.mismatch(order, f"rs2 x{rs2}=0x{observed_rs2:08x}, expected 0x{self.regs[rs2]:08x}")

        if intr:
            self.interrupts += 1
            if observed_next_pc != (parse_hex(row["mtvec"]) & ~3):
                self.mismatch(order, "interrupt target does not match mtvec")
            if parse_hex(row["mcause"]) != 0x8000_000B:
                self.mismatch(order, "interrupt mcause is not machine external interrupt")
            if parse_hex(row["mepc"]) != pc:
                self.mismatch(order, "interrupt mepc does not identify the interrupted instruction")
            self.csrs[0x341] = pc
            self.csrs[0x342] = 0x8000_000B
            old_mie = bool(self.csrs[0x300] & 0x8)
            self.csrs[0x300] = (self.csrs[0x300] & ~0x88) | (0x80 if old_mie else 0)
            self.expected_order = order + 1
            self.expected_pc = observed_next_pc
            self.instructions += 1
            return
        if trap:
            self.traps += 1
            if observed_next_pc != (parse_hex(row["mtvec"]) & ~3):
                self.mismatch(order, "trap target does not match mtvec")
            if observed_rd != 0:
                self.mismatch(order, "trapping instruction wrote a register")
            opcode = insn & 0x7F
            funct3 = field(insn, 14, 12)
            if insn == 0x0000_0073:
                expected_cause = 11
            elif opcode in (0x6F, 0x67, 0x63):
                imm_i = sext(field(insn, 31, 20), 12)
                imm_b = sext((field(insn, 31, 31) << 12) | (field(insn, 7, 7) << 11) |
                             (field(insn, 30, 25) << 5) | (field(insn, 11, 8) << 1), 13)
                imm_j = sext((field(insn, 31, 31) << 20) | (field(insn, 19, 12) << 12) |
                             (field(insn, 20, 20) << 11) | (field(insn, 30, 21) << 1), 21)
                if opcode == 0x6F: target = u32(pc + imm_j)
                elif opcode == 0x67: target = u32((self.regs[rs1] + imm_i) & ~1)
                else: target = u32(pc + imm_b)
                expected_cause = 0 if target & 2 else 2
            elif opcode not in (0x03, 0x23):
                expected_cause = 2
            else:
                address = mem_address
                if opcode == 0x03:
                    if funct3 not in (0, 1, 2, 4, 5):
                        expected_cause = 2
                    else:
                        misaligned = (funct3 == 2 and (address & 3)) or (funct3 in (1, 5) and (address & 1))
                        expected_cause = 4 if misaligned else 5
                else:
                    if funct3 not in (0, 1, 2):
                        expected_cause = 2
                    else:
                        misaligned = (funct3 == 2 and (address & 3)) or (funct3 == 1 and (address & 1))
                        expected_cause = 6 if misaligned else (2 if 0x100 <= address <= 0x1FF and funct3 != 2 else 7)
            if parse_hex(row["mcause"]) != expected_cause:
                self.mismatch(order, f"mcause {parse_hex(row['mcause'])}, expected {expected_cause}")
            if parse_hex(row["mepc"]) != pc:
                self.mismatch(order, "trap mepc does not identify the faulting instruction")
            if observed_rd or observed_rd_value:
                self.mismatch(order, "trapping instruction changed architectural destination state")
            self.csrs[0x341] = pc
            self.csrs[0x342] = expected_cause
            old_mie = bool(self.csrs[0x300] & 0x8)
            self.csrs[0x300] = (self.csrs[0x300] & ~0x88) | (0x80 if old_mie else 0)
            self.expected_order = order + 1
            self.expected_pc = observed_next_pc
            self.instructions += 1
            return

        opcode = insn & 0x7F
        funct3 = field(insn, 14, 12)
        funct7 = field(insn, 31, 25)
        rd = field(insn, 11, 7)
        expected_rd = 0
        expected_value = 0
        next_pc = u32(pc + 4)
        legal = True

        imm_i = sext(field(insn, 31, 20), 12)
        imm_s = sext((field(insn, 31, 25) << 5) | field(insn, 11, 7), 12)
        imm_b = sext((field(insn, 31, 31) << 12) | (field(insn, 7, 7) << 11) |
                     (field(insn, 30, 25) << 5) | (field(insn, 11, 8) << 1), 13)
        imm_u = insn & 0xFFFFF000
        imm_j = sext((field(insn, 31, 31) << 20) | (field(insn, 19, 12) << 12) |
                     (field(insn, 20, 20) << 11) | (field(insn, 30, 21) << 1), 21)

        if opcode == 0x37:
            expected_rd, expected_value = rd, imm_u
        elif opcode == 0x17:
            expected_rd, expected_value = rd, u32(pc + imm_u)
        elif opcode == 0x6F:
            expected_rd, expected_value = rd, u32(pc + 4)
            next_pc = u32(pc + imm_j)
        elif opcode == 0x67 and funct3 == 0:
            expected_rd, expected_value = rd, u32(pc + 4)
            next_pc = u32((self.regs[rs1] + imm_i) & ~1)
        elif opcode == 0x63:
            a, b = self.regs[rs1], self.regs[rs2]
            taken = {
                0: a == b, 1: a != b, 4: signed(a) < signed(b),
                5: signed(a) >= signed(b), 6: a < b, 7: a >= b,
            }.get(funct3)
            legal = taken is not None
            if taken:
                next_pc = u32(pc + imm_b)
        elif opcode == 0x13:
            a = self.regs[rs1]
            if funct3 == 0: expected_value = u32(a + imm_i)
            elif funct3 == 2: expected_value = int(signed(a) < signed(imm_i))
            elif funct3 == 3: expected_value = int(a < imm_i)
            elif funct3 == 4: expected_value = a ^ imm_i
            elif funct3 == 6: expected_value = a | imm_i
            elif funct3 == 7: expected_value = a & imm_i
            elif funct3 == 1 and funct7 == 0: expected_value = u32(a << field(insn, 24, 20))
            elif funct3 == 5 and funct7 == 0: expected_value = a >> field(insn, 24, 20)
            elif funct3 == 5 and funct7 == 0x20: expected_value = u32(signed(a) >> field(insn, 24, 20))
            else: legal = False
            expected_rd = rd
        elif opcode == 0x33:
            a, b = self.regs[rs1], self.regs[rs2]
            operations = {
                (0x00, 0): u32(a + b), (0x20, 0): u32(a - b),
                (0x00, 1): u32(a << (b & 31)), (0x00, 2): int(signed(a) < signed(b)),
                (0x00, 3): int(a < b), (0x00, 4): a ^ b,
                (0x00, 5): a >> (b & 31), (0x20, 5): u32(signed(a) >> (b & 31)),
                (0x00, 6): a | b, (0x00, 7): a & b,
            }
            legal = (funct7, funct3) in operations
            expected_rd, expected_value = rd, operations.get((funct7, funct3), 0)
        elif opcode == 0x03:
            expected_rd = rd
            shift = (mem_address & 3) * 8
            expected_mask = ({0: 0x1, 1: 0x3, 2: 0xF, 4: 0x1, 5: 0x3}.get(funct3, 0) << (mem_address & 3)) & 0xF
            if rmask != expected_mask:
                self.mismatch(order, f"load mask 0x{rmask:x}, expected 0x{expected_mask:x}")
            mmio = 0x100 <= mem_address <= 0x1FF
            model_base = ((mem_address - 0x8000) if mem_address >= 0x8000 else mem_address) & ~3
            model_word = mem_rdata if mmio else self.memory.get(model_base, 0)
            if not mmio and mem_rdata != model_word:
                self.mismatch(order, f"load source 0x{mem_rdata:08x}, expected modeled memory 0x{model_word:08x}")
            shifted = model_word >> shift
            expected_value = {
                0: sext(shifted & 0xFF, 8), 1: sext(shifted & 0xFFFF, 16),
                2: model_word, 4: shifted & 0xFF, 5: shifted & 0xFFFF,
            }.get(funct3, 0)
            legal = funct3 in (0, 1, 2, 4, 5) and rmask != 0
        elif opcode == 0x23:
            legal = funct3 in (0, 1, 2) and wmask != 0
            expected_mask = ({0: 0x1, 1: 0x3, 2: 0xF}.get(funct3, 0) << (mem_address & 3)) & 0xF
            if wmask != expected_mask:
                self.mismatch(order, f"store mask 0x{wmask:x}, expected 0x{expected_mask:x}")
            base = ((mem_address - 0x8000) if mem_address >= 0x8000 else mem_address) & ~3
            word = self.memory.get(base, 0)
            offset = mem_address & 3
            for lane in range(4):
                if wmask & (1 << lane):
                    source_lane = lane - offset
                    byte = (mem_wdata >> (source_lane * 8)) & 0xFF
                    word = (word & ~(0xFF << (lane * 8))) | (byte << (lane * 8))
            if not 0x100 <= mem_address <= 0x1FF:
                self.memory[base] = u32(word)
        elif opcode == 0x0F:
            legal = funct3 == 0
        elif opcode == 0x73:
            if insn in (0x00100073, 0x30200073):
                if insn == 0x30200073:
                    next_pc = self.csrs[0x341]
                    mpie = bool(self.csrs[0x300] & 0x80)
                    self.csrs[0x300] = (self.csrs[0x300] | 0x80) & ~0x8
                    if mpie: self.csrs[0x300] |= 0x8
            elif funct3:
                csr = field(insn, 31, 20)
                legal = csr in self.csrs
                expected_rd, expected_value = rd, self.csrs.get(csr, 0)
                source = rs1 if funct3 & 4 else self.regs[rs1]
                mode = funct3 & 3
                if mode == 1: new_value = source
                elif mode == 2: new_value = expected_value | source
                elif mode == 3: new_value = expected_value & ~source
                else: new_value = expected_value; legal = False
                if legal and (mode == 1 or source != 0):
                    if csr == 0x300: new_value &= 0x88
                    if csr == 0x304: new_value &= 0x800
                    if csr in (0x305, 0x341): new_value &= ~3
                    self.csrs[csr] = u32(new_value)
            else:
                legal = False
        else:
            legal = False

        if not legal:
            self.mismatch(order, f"unexpected non-trapping instruction 0x{insn:08x}")
        if next_pc != observed_next_pc:
            self.mismatch(order, f"next PC 0x{observed_next_pc:08x}, expected 0x{next_pc:08x}")
        if expected_rd == 0:
            expected_value = 0
        if observed_rd != expected_rd:
            self.mismatch(order, f"rd x{observed_rd}, expected x{expected_rd}")
        if observed_rd and u32(observed_rd_value) != u32(expected_value):
            self.mismatch(order, f"rd value 0x{observed_rd_value:08x}, expected 0x{expected_value:08x}")
        if observed_rd:
            self.regs[observed_rd] = u32(observed_rd_value)
        self.regs[0] = 0
        self.expected_order = order + 1
        self.expected_pc = next_pc
        self.instructions += 1

    def check(self, trace: Path) -> CheckResult:
        with trace.open(newline="") as handle:
            for row in csv.DictReader(handle):
                if all(value is not None for value in row.values()):
                    self.check_row(row)
        return CheckResult(self.instructions, self.traps, self.interrupts, self.mismatches)


def check_trace(trace: Path, instruction_manifest: Path | None = None,
                data_image: Path | None = None) -> CheckResult:
    return RV32ISS(instruction_manifest, data_image).check(trace)
