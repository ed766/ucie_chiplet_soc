from __future__ import annotations

import os
from pathlib import Path
from typing import Tuple

import cocotb
from cocotb.clock import Clock
from cocotb.result import TestFailure
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb_coverage.coverage import coverage_db

from .apb import ApbMaster, decode_status
from .coverage_power import PowerCoverage, PowerState
from .metrics import MetricsRecorder

CTRL_ADDR = 0x000
STATUS_ADDR = 0x004
TIMER_RELOAD = 0x100
TIMER_VALUE = 0x104
TIMER_CTRL = 0x108


async def _apply_reset(dut) -> None:
    dut.rst_n.value = 0
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.paddr.value = 0
    dut.pwdata.value = 0
    await ClockCycles(dut.clk, 8)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 8)


async def _read_state(apb: ApbMaster, dut, coverage: PowerCoverage) -> Tuple[PowerState, int]:
    resp = await apb.read(STATUS_ADDR)
    status = decode_status(resp.data)
    state = PowerState(status["pst_state"])
    coverage.sample(
        state=state,
        iso_pd1=int(dut.iso_pd1_n.value),
        iso_pd2=int(dut.iso_pd2_n.value),
        pd1_sw_en=int(dut.pd1_sw_en.value),
        pd2_sw_en=int(dut.pd2_sw_en.value),
        save_pd2=int(dut.save_pd2.value),
        restore_pd2=int(dut.restore_pd2.value),
        wake_irq=int(dut.u_pwr.wake_irq.value),
    )
    return state, status["wake_irq"]


async def _wait_for_state(
    apb: ApbMaster,
    dut,
    coverage: PowerCoverage,
    target: PowerState,
    max_attempts: int = 80,
) -> None:
    for _ in range(max_attempts):
        state, _ = await _read_state(apb, dut, coverage)
        if state == target:
            return
        await ClockCycles(dut.clk_32k, 2)
    raise TestFailure(f"State machine did not reach {target.name} within {max_attempts} polls")


@cocotb.test()
async def test_soc_top_power_sequences(dut) -> None:
    """Exercise RUN→SLEEP→RUN and RUN→DEEP_SLEEP→RUN flows and log metrics."""

    reports_root = Path(os.getenv("REPORTS_DIR", "reports"))
    func_cov_dir = reports_root / "functional"
    func_cov_dir.mkdir(parents=True, exist_ok=True)
    regression_dir = reports_root / "regression"
    regression_dir.mkdir(parents=True, exist_ok=True)

    metrics = MetricsRecorder(regression_dir)
    metrics.begin_test()
    coverage = PowerCoverage(initial_state=PowerState.RUN)

    # Free-running clocks: fast core clock and 32 kHz reference.
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_32k, 31250, units="ns").start())

    await _apply_reset(dut)

    apb = ApbMaster("soc_top", dut, dut.clk)
    await apb.reset()

    save_seen = False
    restore_seen = False
    wake_irq_seen = False

    async def _watch_sequences():
        nonlocal save_seen, restore_seen, wake_irq_seen
        while True:
            await RisingEdge(dut.clk_32k)
            save_seen |= int(dut.save_pd2.value) == 1
            restore_seen |= int(dut.restore_pd2.value) == 1
            wake_irq_seen |= int(dut.u_pwr.wake_irq.value) == 1

    cocotb.start_soon(_watch_sequences())

    def check(name: str, condition: bool, note: str = "") -> None:
        metrics.record_assertion(name, failed=not condition, notes=note)
        if not condition:
            detail = f"{name} failed"
            if note:
                detail += f": {note}"
            raise TestFailure(detail)

    status = "fail"
    try:
        # Program timer for a short wake-up interval and enable it.
        await apb.write(TIMER_RELOAD, 8)
        await apb.write(TIMER_VALUE, 8)
        await apb.write(TIMER_CTRL, 1)

        # Baseline state should be RUN.
        state, wake_flag = await _read_state(apb, dut, coverage)
        check("initial_state_run", state == PowerState.RUN)
        check("initial_wake_flag_clear", wake_flag == 0)

        # Request SLEEP and wait for the FSM to settle.
        await apb.write(CTRL_ADDR, 0x1)
        await _wait_for_state(apb, dut, coverage, PowerState.SLEEP)
        check("sleep_iso_pd1", int(dut.iso_pd1_n.value) == 0)
        check("sleep_pd1_sw_off", int(dut.pd1_sw_en.value) == 0)
        check("sleep_pd2_sw_on", int(dut.pd2_sw_en.value) == 1)

        # SLEEP should auto-wake via timer.
        await _wait_for_state(apb, dut, coverage, PowerState.RUN)
        check("wake_restore_seen", restore_seen)
        check("wake_irq_latched", wake_irq_seen)

        # Clear control bits.
        await apb.write(CTRL_ADDR, 0x0)
        await ClockCycles(dut.clk_32k, 4)

        # Disable timer to avoid additional wake-ups during deep sleep scenario.
        await apb.write(TIMER_CTRL, 0)

        # Request DEEP_SLEEP and wait for sequencing.
        await apb.write(CTRL_ADDR, 0x2)
        await _wait_for_state(apb, dut, coverage, PowerState.DEEP_SLEEP)
        check("deepsleep_iso_pd1", int(dut.iso_pd1_n.value) == 0)
        check("deepsleep_iso_pd2", int(dut.iso_pd2_n.value) == 0)
        check("deepsleep_pd1_sw_off", int(dut.pd1_sw_en.value) == 0)
        check("deepsleep_pd2_sw_off", int(dut.pd2_sw_en.value) == 0)
        check("save_pulse_seen", save_seen)

        # Return to RUN.
        await apb.write(CTRL_ADDR, 0x0)
        await _wait_for_state(apb, dut, coverage, PowerState.RUN)
        check("restore_pulse_seen", restore_seen)

        status = "pass"
    finally:
        metrics.end_test(name="soc_top.power_sequences", status=status)
        coverage_db.export_to_yaml(str(func_cov_dir / "power_cov.yaml"))
        metrics.emit_json()
