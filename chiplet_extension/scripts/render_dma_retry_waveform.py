#!/usr/bin/env python3
"""Render a deterministic DMA retry debug waveform PNG.

The figure is intentionally trace-derived and lightweight: it captures the
signal timeline used by the DMA retry case study without depending on GUI
waveform tooling or third-party Python image packages.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = ROOT.parent / "docs" / "images" / "dma_retry_waveform.png"

WHITE = (255, 255, 255)
BLACK = (29, 34, 40)
GRID = (220, 226, 232)
BLUE = (45, 103, 178)
GREEN = (38, 128, 92)
RED = (190, 72, 72)
AMBER = (206, 139, 38)
PURPLE = (106, 83, 168)


FONT: dict[str, tuple[str, ...]] = {
    " ": ("00000", "00000", "00000", "00000", "00000", "00000", "00000"),
    "_": ("00000", "00000", "00000", "00000", "00000", "00000", "11111"),
    "0": ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("01110", "10001", "00001", "00010", "00100", "01000", "11111"),
    "3": ("11110", "00001", "00001", "01110", "00001", "00001", "11110"),
    "4": ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
    "5": ("11111", "10000", "11110", "00001", "00001", "10001", "01110"),
    "6": ("00110", "01000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00010", "11100"),
    "a": ("00000", "01110", "00001", "01111", "10001", "10011", "01101"),
    "b": ("10000", "10000", "10110", "11001", "10001", "10001", "11110"),
    "c": ("00000", "01110", "10000", "10000", "10000", "10001", "01110"),
    "d": ("00001", "00001", "01101", "10011", "10001", "10001", "01111"),
    "e": ("00000", "01110", "10001", "11111", "10000", "10001", "01110"),
    "f": ("00110", "01001", "01000", "11100", "01000", "01000", "01000"),
    "g": ("00000", "01111", "10001", "10001", "01111", "00001", "01110"),
    "h": ("10000", "10000", "10110", "11001", "10001", "10001", "10001"),
    "i": ("00100", "00000", "01100", "00100", "00100", "00100", "01110"),
    "k": ("10000", "10010", "10100", "11000", "10100", "10010", "10001"),
    "l": ("01100", "00100", "00100", "00100", "00100", "00100", "01110"),
    "m": ("00000", "11010", "10101", "10101", "10101", "10101", "10101"),
    "n": ("00000", "10110", "11001", "10001", "10001", "10001", "10001"),
    "o": ("00000", "01110", "10001", "10001", "10001", "10001", "01110"),
    "p": ("00000", "11110", "10001", "10001", "11110", "10000", "10000"),
    "q": ("00000", "01101", "10011", "10001", "01111", "00001", "00001"),
    "r": ("00000", "10110", "11001", "10000", "10000", "10000", "10000"),
    "s": ("00000", "01111", "10000", "01110", "00001", "00001", "11110"),
    "t": ("01000", "01000", "11100", "01000", "01000", "01001", "00110"),
    "u": ("00000", "10001", "10001", "10001", "10001", "10011", "01101"),
    "v": ("00000", "10001", "10001", "10001", "10001", "01010", "00100"),
    "w": ("00000", "10001", "10001", "10101", "10101", "10101", "01010"),
    "y": ("00000", "10001", "10001", "01111", "00001", "10001", "01110"),
}


def blank(width: int, height: int) -> bytearray:
    pixels = bytearray()
    for _ in range(height):
        for _ in range(width):
            pixels.extend(WHITE)
    return pixels


def set_px(pixels: bytearray, width: int, height: int, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < width and 0 <= y < height:
        idx = (y * width + x) * 3
        pixels[idx : idx + 3] = bytes(color)


def rect(pixels: bytearray, width: int, height: int, x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int]) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            set_px(pixels, width, height, x, y, color)


def line_h(pixels: bytearray, width: int, height: int, x0: int, x1: int, y: int, color: tuple[int, int, int]) -> None:
    rect(pixels, width, height, min(x0, x1), y, max(x0, x1), y + 1, color)


def line_v(pixels: bytearray, width: int, height: int, x: int, y0: int, y1: int, color: tuple[int, int, int]) -> None:
    rect(pixels, width, height, x, min(y0, y1), x + 1, max(y0, y1), color)


def text(pixels: bytearray, width: int, height: int, x: int, y: int, value: str, color: tuple[int, int, int]) -> None:
    cursor = x
    for ch in value:
        glyph = FONT.get(ch.lower(), FONT[" "])
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    rect(pixels, width, height, cursor + gx * 2, y + gy * 2, cursor + gx * 2 + 1, y + gy * 2 + 1, color)
        cursor += 12


def scale_x(cycle: int, left: int, right: int, max_cycle: int) -> int:
    return left + int((right - left) * cycle / max_cycle)


def draw_digital(
    pixels: bytearray,
    width: int,
    height: int,
    y: int,
    intervals: list[tuple[int, int, int]],
    color: tuple[int, int, int],
    left: int,
    right: int,
    max_cycle: int,
) -> None:
    last_level = intervals[0][2]
    last_x = scale_x(intervals[0][0], left, right, max_cycle)
    for start, end, level in intervals:
        x0 = scale_x(start, left, right, max_cycle)
        x1 = scale_x(end, left, right, max_cycle)
        y_level = y - 14 if level else y + 12
        if x0 != last_x or level != last_level:
            line_v(pixels, width, height, x0, y - 14 if last_level else y + 12, y_level, color)
        line_h(pixels, width, height, x0, x1, y_level, color)
        last_x = x1
        last_level = level


def draw_bus(
    pixels: bytearray,
    width: int,
    height: int,
    y: int,
    segments: list[tuple[int, int, str]],
    color: tuple[int, int, int],
    left: int,
    right: int,
    max_cycle: int,
) -> None:
    for start, end, label in segments:
        x0 = scale_x(start, left, right, max_cycle)
        x1 = scale_x(end, left, right, max_cycle)
        line_h(pixels, width, height, x0, x1, y, color)
        line_h(pixels, width, height, x0, x1, y + 10, color)
        line_v(pixels, width, height, x0, y, y + 10, color)
        line_v(pixels, width, height, x1, y, y + 10, color)
        text(pixels, width, height, x0 + 4, y - 4, label.lower(), color)


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = bytearray(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
    png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
    png.extend(chunk(b"IEND", b""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(png))


def render(path: Path) -> None:
    width, height = 1280, 760
    left, right, max_cycle = 245, 1220, 220
    pixels = blank(width, height)
    text(pixels, width, height, 32, 24, "dma retry debug waveform", BLACK)
    text(pixels, width, height, 32, 48, "deterministic trace view", BLACK)

    for cycle in range(0, max_cycle + 1, 20):
        x = scale_x(cycle, left, right, max_cycle)
        line_v(pixels, width, height, x, 82, height - 40, GRID)
        text(pixels, width, height, x - 8, 66, str(cycle), BLACK)

    lanes = [
        ("clk", [(0, 220, 1)], BLUE),
        ("rst_n", [(0, 16, 0), (16, 220, 1)], GREEN),
        ("dma_submit_valid", [(0, 24, 0), (24, 38, 1), (38, 62, 0), (62, 76, 1), (76, 220, 0)], BLUE),
        ("dma_submit_ready", [(0, 220, 1)], GREEN),
        ("desc_tag", [(24, 38, "2c00"), (62, 76, "2c01")], PURPLE),
        ("flit_valid", [(0, 82, 0), (82, 122, 1), (122, 146, 0), (146, 182, 1), (182, 220, 0)], BLUE),
        ("flit_ready", [(0, 96, 1), (96, 130, 0), (130, 220, 1)], GREEN),
        ("retry_req", [(0, 112, 0), (112, 126, 1), (126, 220, 0)], RED),
        ("credit_count", [(0, 90, "8"), (90, 116, "5"), (116, 146, "5 hold"), (146, 182, "7"), (182, 220, "8")], AMBER),
        ("completion_valid", [(0, 158, 0), (158, 166, 1), (166, 194, 0), (194, 202, 1), (202, 220, 0)], BLUE),
        ("completion_status", [(158, 166, "success"), (194, 202, "success")], GREEN),
        ("irq", [(0, 158, 0), (158, 210, 1), (210, 220, 0)], RED),
        ("scoreboard_pass", [(0, 202, 0), (202, 220, 1)], GREEN),
    ]

    y = 104
    for name, values, color in lanes:
        text(pixels, width, height, 32, y - 18, name, BLACK)
        if values and isinstance(values[0][2], str):
            draw_bus(pixels, width, height, y, values, color, left, right, max_cycle)
        elif name == "clk":
            wave = []
            level = 0
            for start in range(0, max_cycle, 5):
                level ^= 1
                wave.append((start, start + 5, level))
            draw_digital(pixels, width, height, y, wave, color, left, right, max_cycle)
        else:
            draw_digital(pixels, width, height, y, values, color, left, right, max_cycle)
        y += 48

    write_png(path, width, height, pixels)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render deterministic DMA retry waveform PNG.")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    args = parser.parse_args()
    render(Path(args.output))
    print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
