#!/usr/bin/env python3
"""Assemble the lightweight RV32 subset used by firmware-driven DV tests."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


REG_RE = re.compile(r"x([0-9]|[12][0-9]|3[01])$")
MEM_RE = re.compile(r"([^()]+)\((x(?:[0-9]|[12][0-9]|3[01]))\)$")


def reg(token: str) -> int:
    match = REG_RE.fullmatch(token.strip())
    if not match:
        raise ValueError(f"invalid register: {token}")
    return int(match.group(1))


def imm(token: str) -> int:
    return int(token.strip(), 0)


def signed(value: int, bits: int) -> int:
    low = -(1 << (bits - 1))
    high = (1 << (bits - 1)) - 1
    if not low <= value <= high:
        raise ValueError(f"immediate {value} does not fit signed {bits} bits")
    return value & ((1 << bits) - 1)


def encode_addi(rd: int, rs1: int, value: int) -> int:
    return (signed(value, 12) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def encode_lw(rd: int, rs1: int, value: int) -> int:
    return (signed(value, 12) << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0x03


def encode_sw(rs2: int, rs1: int, value: int) -> int:
    encoded = signed(value, 12)
    return ((encoded >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | ((encoded & 0x1F) << 7) | 0x23


def encode_beq(rs1: int, rs2: int, offset: int) -> int:
    if offset & 1:
        raise ValueError(f"branch offset must be 2-byte aligned: {offset}")
    encoded = signed(offset, 13)
    return (((encoded >> 12) & 1) << 31) | (((encoded >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (((encoded >> 1) & 0xF) << 8) | (((encoded >> 11) & 1) << 7) | 0x63


def parse_source(path: Path) -> tuple[list[str], dict[str, int]]:
    instructions: list[str] = []
    labels: dict[str, int] = {}
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if ":" in line:
            label, line = line.split(":", 1)
            label = label.strip()
            if not label or label in labels:
                raise ValueError(f"invalid or duplicate label {label!r} in {path}")
            labels[label] = len(instructions) * 4
            line = line.strip()
        if line:
            instructions.append(line)
    return instructions, labels


def assemble_line(line: str, pc: int, labels: dict[str, int]) -> int:
    fields = line.replace(",", " ").split()
    op = fields[0].lower()
    if op == "addi" and len(fields) == 4:
        return encode_addi(reg(fields[1]), reg(fields[2]), imm(fields[3]))
    if op in {"lw", "sw"} and len(fields) == 3:
        match = MEM_RE.fullmatch(fields[2])
        if not match:
            raise ValueError(f"invalid memory operand: {fields[2]}")
        offset = imm(match.group(1))
        base = reg(match.group(2))
        if op == "lw":
            return encode_lw(reg(fields[1]), base, offset)
        return encode_sw(reg(fields[1]), base, offset)
    if op == "beq" and len(fields) == 4:
        target = labels.get(fields[3])
        if target is None:
            raise ValueError(f"unknown branch label: {fields[3]}")
        return encode_beq(reg(fields[1]), reg(fields[2]), target - pc)
    if op == "ebreak" and len(fields) == 1:
        return 0x00100073
    if op == "nop" and len(fields) == 1:
        return 0x00000013
    if op == ".word" and len(fields) == 2:
        return imm(fields[1]) & 0xFFFFFFFF
    raise ValueError(f"unsupported instruction: {line}")


def assemble(source: Path, output: Path) -> None:
    instructions, labels = parse_source(source)
    words = [assemble_line(line, idx * 4, labels) for idx, line in enumerate(instructions)]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(f"{word:08x}\n" for word in words))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    assemble(args.source, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
