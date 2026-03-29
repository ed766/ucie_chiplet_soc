"""Helpers to accumulate verification metrics during cocotb runs."""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

from cocotb.utils import get_sim_time


@dataclass
class TestEntry:
    name: str
    status: str
    wall_seconds: float
    sim_time_ns: int
    seed: Optional[int] = None
    details: Dict[str, int] = field(default_factory=dict)


@dataclass
class AssertionEntry:
    name: str
    failures: int
    notes: str = ""


class MetricsRecorder:
    """Collects regression metrics and emits structured reports."""

    def __init__(self, reports_dir: Path) -> None:
        self.reports_dir = reports_dir
        self.tests: List[TestEntry] = []
        self.assertions: Dict[str, AssertionEntry] = {}
        self._current_start_wall: Optional[float] = None
        self._current_start_sim: Optional[int] = None
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    def begin_test(self) -> None:
        self._current_start_wall = time.perf_counter()
        self._current_start_sim = get_sim_time(units="ns")

    def end_test(
        self,
        name: str,
        status: str,
        seed: Optional[int] = None,
        details: Optional[Dict[str, int]] = None,
    ) -> None:
        if self._current_start_wall is None or self._current_start_sim is None:
            raise RuntimeError("begin_test() must be called before end_test()")
        wall_elapsed = time.perf_counter() - self._current_start_wall
        sim_elapsed = get_sim_time(units="ns") - self._current_start_sim
        self.tests.append(
            TestEntry(
                name=name,
                status=status,
                wall_seconds=wall_elapsed,
                sim_time_ns=sim_elapsed,
                seed=seed,
                details=details or {},
            )
        )
        self._current_start_wall = None
        self._current_start_sim = None

    def record_assertion(self, name: str, failed: bool, notes: str = "") -> None:
        entry = self.assertions.setdefault(name, AssertionEntry(name=name, failures=0, notes=notes))
        if failed:
            entry.failures += 1

    def emit_json(self) -> Path:
        payload = {
            "tests": [
                {
                    "name": t.name,
                    "status": t.status,
                    "wall_seconds": round(t.wall_seconds, 6),
                    "sim_time_ns": int(t.sim_time_ns),
                    **({"seed": t.seed} if t.seed is not None else {}),
                    **({"details": t.details} if t.details else {}),
                }
                for t in self.tests
            ],
            "assertions": {
                name: {"failures": entry.failures, **({"notes": entry.notes} if entry.notes else {})}
                for name, entry in self.assertions.items()
            },
        }
        path = self.reports_dir / "metrics.json"
        path.write_text(json.dumps(payload, indent=2), encoding="ascii")
        return path
