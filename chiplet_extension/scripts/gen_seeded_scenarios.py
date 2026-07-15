#!/usr/bin/env python3
"""Generate bounded seeded-random scenario manifests for optional stress runs."""

from __future__ import annotations

import argparse
import csv
import random
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
REPORT_ROOT = ROOT / "reports"


@dataclass(frozen=True)
class FamilyCfg:
    name: str
    count: int
    default_test: str
    suite: str


FAMILIES = {
    "random_smoke_25": FamilyCfg("random_smoke_25", 25, "random_manifest_scenario", "stress"),
    "stress_retry_50": FamilyCfg("stress_retry_50", 50, "prbs_retry_backpressure", "stress"),
    "power_dma_cross_25": FamilyCfg("power_dma_cross_25", 25, "power_traffic_cross_test", "power"),
}


def choose(rng: random.Random, values: tuple[object, ...]) -> object:
    return values[rng.randrange(len(values))]


def row_for(cfg: FamilyCfg, rng: random.Random, index: int, seed: int) -> dict[str, str]:
    src_bank = int(choose(rng, (0, 1)))
    dst_bank = int(choose(rng, (0, 1)))
    dma_len = int(choose(rng, (1, 2, 4, 8, 12, 16)))
    queue_pressure = str(choose(rng, ("single", "pair", "full_queue")))
    backpressure_cycles = int(choose(rng, (0, 4, 8, 16, 32)))
    crc_fault_at = str(choose(rng, ("none", "early", "mid", "late")))
    lane_fault_type = str(choose(rng, ("none", "single_lane", "burst_lane", "retrain")))
    power_transition_cycle = int(choose(rng, (0, 32, 64, 96, 128)))
    aes_blocks = int(choose(rng, (1, 2, 4, 8)))
    parity_injection = str(choose(rng, ("none", "src", "dst_maint")))
    timeout_profile = str(choose(rng, ("nominal", "low", "high")))
    retry_window = int(choose(rng, (0, 4, 8, 16)))

    if cfg.name == "random_smoke_25":
        # The DMA manifest scenario is a data-integrity stress. Keep link and
        # power faulting disabled here so randomized DMA/memory knobs are the
        # only source of expected behavior.
        backpressure_cycles = 0
        crc_fault_at = "none"
        lane_fault_type = "none"
        power_transition_cycle = 0
        timeout_profile = "nominal"
        retry_window = 0
        dma_len = int(choose(rng, (8, 12, 16)))
        queue_pressure = "single"
    elif cfg.name == "stress_retry_50":
        # Link retry stress uses the PRBS retry/backpressure path. DMA, memory,
        # and power knobs are recorded for traceability but constrained inert.
        queue_pressure = "single"
        parity_injection = "none"
        timeout_profile = "nominal"
        power_transition_cycle = 0
        crc_fault_at = str(choose(rng, ("early", "mid", "late")))
        lane_fault_type = "none"
        backpressure_cycles = int(choose(rng, (8, 16, 32)))
        retry_window = int(choose(rng, (4, 8, 16)))
    elif cfg.name == "power_dma_cross_25":
        # The power-cross scenario already combines queued DMA, retry/recovery,
        # backpressure, CRYPTO_ONLY, and SLEEP. Do not add unrelated memory or
        # lane-fault errors that would change the expected outcome.
        parity_injection = "none"
        timeout_profile = "nominal"
        dma_len = 4
        queue_pressure = "pair"
        lane_fault_type = "none"
        crc_fault_at = str(choose(rng, ("early", "mid", "late")))
        backpressure_cycles = int(choose(rng, (8, 16, 32)))
        retry_window = int(choose(rng, (4, 8, 16)))

    # Integrity-fault rows intentionally use a single DMA operation so the
    # expected error path is unambiguous.
    if parity_injection != "none":
        queue_pressure = "single"
    artifact_stem = f"{cfg.name}_{index:03d}_seed{seed:08x}"
    return {
        "family": cfg.name,
        "index": str(index),
        "seed": str(seed),
        "suite": cfg.suite,
        "representative_test": cfg.default_test,
        "dma_len": str(dma_len),
        "src_bank": str(src_bank),
        "dst_bank": str(dst_bank),
        "queue_pressure": queue_pressure,
        "backpressure_cycles": str(backpressure_cycles),
        "crc_fault_at": crc_fault_at,
        "lane_fault_type": lane_fault_type,
        "power_transition_cycle": str(power_transition_cycle),
        "aes_blocks": str(aes_blocks),
        "parity_injection": parity_injection,
        "timeout_profile": timeout_profile,
        "retry_window": str(retry_window),
        "coverage_csv": f"chiplet_extension/reports/{artifact_stem}_coverage.csv",
        "scoreboard_csv": f"chiplet_extension/reports/{artifact_stem}_scoreboard.csv",
        "power_csv": f"chiplet_extension/reports/{artifact_stem}_power.csv",
    }


def write_manifest(cfg: FamilyCfg, base_seed: int, output: Path) -> None:
    family_salt = sum((idx + 1) * ord(ch) for idx, ch in enumerate(cfg.name))
    rng = random.Random(base_seed ^ family_salt)
    rows: list[dict[str, str]] = []
    for index in range(cfg.count):
        seed = rng.randrange(1, 2**31 - 1)
        rows.append(row_for(cfg, rng, index, seed))

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate seeded-random stress scenario manifests.")
    parser.add_argument("--family", choices=sorted(FAMILIES), required=True)
    parser.add_argument("--seed", type=int, default=20260426)
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    cfg = FAMILIES[args.family]
    output = Path(args.output) if args.output else REPORT_ROOT / f"{cfg.name}_manifest.csv"
    write_manifest(cfg, args.seed, output)
    print(f"Wrote {cfg.count} scenarios to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
