#!/usr/bin/env python3
"""Render the firmware-driven DMA trace as a deterministic PNG."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from render_dma_retry_waveform import (
    AMBER,
    BLACK,
    BLUE,
    GREEN,
    GRID,
    PURPLE,
    RED,
    blank,
    draw_bus,
    draw_digital,
    line_v,
    scale_x,
    text,
    write_png,
)


ROOT = Path(__file__).resolve().parent.parent


def intervals(rows: list[dict[str, str]], field: str) -> list[tuple[int, int, int]]:
    values = [(int(row["cycle"]), int(row[field], 0)) for row in rows]
    result: list[tuple[int, int, int]] = []
    start, level = values[0]
    previous = start
    for cycle, value in values[1:]:
        if value != level:
            result.append((start, previous + 1, level))
            start, level = cycle, value
        previous = cycle
    result.append((start, previous + 1, level))
    return result


def bus_segments(rows: list[dict[str, str]], field: str, enable: str) -> list[tuple[int, int, str]]:
    result: list[tuple[int, int, str]] = []
    for row in rows:
        if int(row[enable], 0):
            cycle = int(row["cycle"])
            result.append((cycle, cycle + 2, row[field].lower()))
    return result


def render(trace: Path, output: Path) -> None:
    with trace.open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise RuntimeError(f"empty firmware trace: {trace}")

    width, height = 1400, 720
    left, right = 260, 1340
    first_cycle = int(rows[0]["cycle"])
    max_cycle = int(rows[-1]["cycle"]) + 2
    shifted = []
    for row in rows:
        item = dict(row)
        item["cycle"] = str(int(row["cycle"]) - first_cycle)
        shifted.append(item)
    span = max_cycle - first_cycle
    pixels = blank(width, height)
    text(pixels, width, height, 28, 22, "rv32 firmware driven dma", BLACK)
    text(pixels, width, height, 28, 48, "actual verilator trace", BLACK)

    for cycle in range(0, span + 1, 20):
        x = scale_x(cycle, left, right, span)
        line_v(pixels, width, height, x, 80, height - 32, GRID)
        text(pixels, width, height, x - 8, 64, str(cycle + first_cycle), BLACK)

    lanes = [
        ("commit_valid", "commit_valid", BLUE),
        ("apb_select", "psel", PURPLE),
        ("apb_enable", "penable", PURPLE),
        ("apb_ready", "pready", GREEN),
        ("apb_write", "pwrite", AMBER),
        ("submit_accept", "submit_accept", BLUE),
        ("completion_push", "completion_push", GREEN),
        ("irq", "irq", RED),
        ("cpu_halted", "halted", BLACK),
    ]
    y = 105
    for label, field, color in lanes:
        text(pixels, width, height, 24, y - 18, label, BLACK)
        draw_digital(pixels, width, height, y, intervals(shifted, field), color, left, right, span)
        y += 52

    text(pixels, width, height, 24, y - 14, "apb_addr", BLACK)
    draw_bus(pixels, width, height, y, bus_segments(shifted, "paddr", "psel"), PURPLE, left, right, span)
    y += 54
    text(pixels, width, height, 24, y - 14, "commit_pc", BLACK)
    draw_bus(pixels, width, height, y, bus_segments(shifted, "commit_pc", "commit_valid"), BLUE, left, right, span)

    write_png(output, width, height, pixels)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace", default=str(ROOT / "build" / "firmware_soc" / "firmware_dma_trace.csv"))
    parser.add_argument("--output", default=str(ROOT.parent / "docs" / "images" / "firmware_dma_waveform.png"))
    args = parser.parse_args()
    render(Path(args.trace), Path(args.output))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
