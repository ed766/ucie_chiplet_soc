#!/usr/bin/env python3
"""Normalize the legacy retirement CSV into standard single-channel RVFI rows."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.input.open(newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if all(value is not None for value in row.values())]
    output = []
    pending_intr = False
    order = 0
    for row in rows:
        if row["intr"] == "1":
            pending_intr = True
            continue
        normalized = dict(row)
        normalized["order"] = str(order)
        normalized["intr"] = str(int(pending_intr))
        normalized["halt"] = "0"
        normalized["mode"] = "3"
        normalized["ixl"] = "1"
        output.append(normalized)
        pending_intr = False
        order += 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fields = list(output[0]) if output else []
    with args.output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader(); writer.writerows(output)
    print(f"Standard RVFI: {len(rows)} legacy events -> {len(output)} architectural retires")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
