#!/usr/bin/env python3
"""Build freestanding RV32I/Zicsr firmware images without a runtime library."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from pathlib import Path

from rv32_toolchain import tool

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "firmware_c"
DEFAULT_BUILD = ROOT / "build" / "firmware_c" / "images"

SCENARIOS = {
    "polling_dma": 0,
    "interrupt_dma": 1,
    "back_to_back": 2,
    "queue_full_recovery": 3,
    "timeout_handler": 4,
    "parity_error": 5,
    "invalid_source": 6,
    "sleep_resume": 7,
    "apb_wait_trap": 8,
    "reset_mid_wait": 9,
    "isa_matrix": 10,
    "operand_corner_matrix": 11,
    "csr_state_matrix": 12,
    "interrupt_before_after_retire": 13,
    "interrupt_during_apb_wait": 14,
    "interrupt_mask_pending_enable": 15,
    "apb_wait_depth_matrix": 16,
    "apb_reset_phase_matrix": 17,
    "apb_access_legality_matrix": 18,
    "dma_length_bank_matrix": 19,
    "dma_completion_pressure_irq": 20,
    "dma_tag_reuse_recovery": 21,
    "power_active_dma_matrix": 22,
    "power_completion_pending_matrix": 23,
    "c_initialized_data_sections": 26,
    "c_abi_stack_call_matrix": 27,
    "rv32_decode_legality_matrix": 28,
    "rv32_control_flow_boundary_matrix": 29,
    "rv32_sram_boundary_fault_matrix": 30,
    "csr_illegal_mask_alignment_matrix": 31,
    "irq_trap_priority_matrix": 32,
    "irq_level_mret_matrix": 33,
    "reset_irq_handler_matrix": 34,
    "apb_atomicity_wait_error_matrix": 35,
    "firmware_completion_mode_error_power_matrix": 36,
}


def binary_to_word_hex(binary: Path, output: Path) -> None:
    data = binary.read_bytes()
    if len(data) % 4:
        data += bytes(4 - len(data) % 4)
    output.write_text(
        "".join(f"{int.from_bytes(data[i:i+4], 'little'):08x}\n" for i in range(0, len(data), 4))
    )


def binary_to_sparse_word_hex(binary: Path, output: Path, base_address: int) -> None:
    data = binary.read_bytes()
    if len(data) % 4:
        data += bytes(4 - len(data) % 4)
    lines = [f"@{base_address // 4:08x}"]
    lines.extend(f"{int.from_bytes(data[i:i+4], 'little'):08x}" for i in range(0, len(data), 4))
    output.write_text("\n".join(lines) + "\n")


def write_instruction_manifest(disassembly: str, output: Path) -> None:
    rows = []
    pattern = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+", re.MULTILINE)
    for match in pattern.finditer(disassembly):
        rows.append({"pc": f"{int(match.group(1), 16):08x}", "insn": match.group(2).lower()})
    # The ROM feeder initializes unused words to EBREAK so a returned C program
    # terminates deterministically. Record that verification-visible sentinel.
    if rows:
        rows.append({"pc": f"{int(rows[-1]['pc'], 16) + 4:08x}", "insn": "00100073"})
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("pc", "insn"))
        writer.writeheader()
        writer.writerows(rows)


def build_one(
    name: str,
    scenario_id: int,
    output_dir: Path,
    *,
    defines: dict[str, int] | None = None,
    extra_sources: list[Path] | None = None,
) -> dict[str, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    elf = output_dir / f"{name}.elf"
    binary = output_dir / f"{name}.bin"
    hex_file = output_dir / f"{name}.hex"
    data_binary = output_dir / f"{name}.data.bin"
    data_hex = output_dir / f"{name}.data.hex"
    disassembly = output_dir / f"{name}.dis"
    manifest = output_dir / f"{name}.instructions.csv"
    map_file = output_dir / f"{name}.map"
    gcc = tool("gcc")
    objcopy = tool("objcopy")
    objdump = tool("objdump")
    command = [
        gcc,
        "-march=rv32i_zicsr",
        "-mabi=ilp32",
        "-Os",
        "-ffreestanding",
        "-nostdlib",
        "-fno-builtin",
        "-fno-pic",
        "-fno-stack-protector",
        "-msmall-data-limit=0",
        "-mno-relax",
        f"-DSCENARIO_ID={scenario_id}",
        *(f"-D{key}={value}" for key, value in sorted((defines or {}).items())),
        f"-I{SOURCE}",
        str(SOURCE / "crt0.S"),
        str(SOURCE / "isa_matrix.S"),
        str(SOURCE / "extended_matrix.S"),
        *(str(path) for path in (extra_sources or [])),
        str(SOURCE / "scenario.c"),
        f"-T{SOURCE / 'link.ld'}",
        f"-Wl,-Map={map_file}",
        "-Wl,--build-id=none",
        "-o",
        str(elf),
    ]
    subprocess.run(command, check=True)
    subprocess.run([objcopy, "-O", "binary", "--only-section=.text", str(elf), str(binary)], check=True)
    subprocess.run([objcopy, "-O", "binary", "--only-section=.rodata", "--only-section=.data",
                    str(elf), str(data_binary)], check=True)
    binary_to_word_hex(binary, hex_file)
    binary_to_sparse_word_hex(data_binary, data_hex, 0x2000)
    disassembly_text = subprocess.run(
        [objdump, "-d", "-M", "no-aliases", str(elf)], check=True,
        capture_output=True, text=True).stdout
    disassembly.write_text(disassembly_text)
    write_instruction_manifest(disassembly_text, manifest)
    return {"elf": elf, "hex": hex_file, "data_hex": data_hex,
            "manifest": manifest, "disassembly": disassembly}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_BUILD)
    parser.add_argument("--scenario", action="append", choices=sorted(SCENARIOS))
    args = parser.parse_args()
    selected = args.scenario or list(SCENARIOS)
    for name in selected:
        artifacts = build_one(name, SCENARIOS[name], args.output_dir)
        print(f"{name}: {artifacts['hex']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
