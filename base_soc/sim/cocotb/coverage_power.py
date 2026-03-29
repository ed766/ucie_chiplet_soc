"""Functional coverage collection for soc_top power management paths."""

from __future__ import annotations

from dataclasses import dataclass
from enum import IntEnum
from typing import Iterable

from cocotb_coverage.coverage import CoverCross, CoverPoint


class PowerState(IntEnum):
    RUN = 0
    SLEEP = 1
    CRYPTO_ONLY = 2
    DEEP_SLEEP = 3


STATE_LABELS = {
    PowerState.RUN: "RUN",
    PowerState.SLEEP: "SLEEP",
    PowerState.CRYPTO_ONLY: "CRYPTO_ONLY",
    PowerState.DEEP_SLEEP: "DEEP_SLEEP",
}

# Only RUN, SLEEP, and DEEP_SLEEP are reachable through the firmware-facing
# control register. CRYPTO_ONLY is reserved; exclude it from coverage targets so
# the closure metric is meaningful.
ACTIVE_STATES = (PowerState.RUN, PowerState.SLEEP, PowerState.DEEP_SLEEP)


@dataclass
class PowerSample:
    state: PowerState
    prev_state: PowerState
    iso_pd1: int
    iso_pd2: int
    pd1_sw_en: int
    pd2_sw_en: int
    save_pd2: int
    restore_pd2: int
    wake_irq: int


@CoverPoint(
    "aon.pst.state",
    xf=lambda s: int(s.state),
    bins=[int(p) for p in ACTIVE_STATES],
    rel=lambda s: STATE_LABELS[PowerState(s)],
    at_least=1,
)
def _cover_state(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.pst.transition",
    xf=lambda s: (int(s.prev_state), int(s.state)),
    bins=[(int(a), int(b)) for a in ACTIVE_STATES for b in ACTIVE_STATES if a != b],
    at_least=1,
)
def _cover_transition(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.power.iso_pd1",
    xf=lambda s: (int(s.state), int(s.iso_pd1)),
    bins=[(int(state), iso) for state in ACTIVE_STATES for iso in (0, 1)],
    at_least=1,
)
def _cover_iso_pd1(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.power.iso_pd2",
    xf=lambda s: (int(s.state), int(s.iso_pd2)),
    bins=[(int(state), iso) for state in ACTIVE_STATES for iso in (0, 1)],
    at_least=1,
)
def _cover_iso_pd2(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.power.save",
    xf=lambda s: int(s.save_pd2),
    bins=[0, 1],
    at_least=1,
)
def _cover_save(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.power.restore",
    xf=lambda s: int(s.restore_pd2),
    bins=[0, 1],
    at_least=1,
)
def _cover_restore(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverPoint(
    "aon.power.wake_irq",
    xf=lambda s: int(s.wake_irq),
    bins=[0, 1],
    at_least=1,
)
def _cover_wake(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


@CoverCross(
    "aon.pst.state_vs_iso",
    items=[_cover_state, _cover_iso_pd1, _cover_iso_pd2],
)
def _cross_state_iso(_sample: PowerSample) -> None:  # pragma: no cover - cocotb coverage hook
    pass


class PowerCoverage:
    """Collects and samples power sequencing coverage."""

    def __init__(self, initial_state: PowerState) -> None:
        self._prev_state = initial_state

    def sample(
        self,
        state: PowerState,
        iso_pd1: int,
        iso_pd2: int,
        pd1_sw_en: int,
        pd2_sw_en: int,
        save_pd2: int,
        restore_pd2: int,
        wake_irq: int,
    ) -> None:
        sample = PowerSample(
            state=state,
            prev_state=self._prev_state,
            iso_pd1=iso_pd1,
            iso_pd2=iso_pd2,
            pd1_sw_en=pd1_sw_en,
            pd2_sw_en=pd2_sw_en,
            save_pd2=save_pd2,
            restore_pd2=restore_pd2,
            wake_irq=wake_irq,
        )
        _cover_state(sample)
        if state != self._prev_state:
            _cover_transition(sample)
        _cover_iso_pd1(sample)
        _cover_iso_pd2(sample)
        _cover_save(sample)
        _cover_restore(sample)
        _cover_wake(sample)
        _cross_state_iso(sample)

        self._prev_state = state
