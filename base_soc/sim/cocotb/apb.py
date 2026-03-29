"""APB-Lite utilities for cocotb testbenches.

The soc_top design exposes a simple APB slave port. This module provides a
master-side driver that handles SETUP/ENABLE phases and retries until PREADY
is asserted. It keeps the rest of the testbench focused on scenario intent
instead of protocol bookkeeping.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import cocotb
from cocotb.handle import SimHandleBase
from cocotb.log import SimLog
from cocotb.triggers import ReadOnly, RisingEdge


@dataclass
class ApbResponse:
    """Result of an APB transfer."""

    data: int
    slverr: int


class ApbMaster:
    """Cycle-accurate APB-Lite master for cocotb."""

    def __init__(self, name: str, bus: SimHandleBase, clk: SimHandleBase):
        self._log = SimLog(f"{name}.ApbMaster")
        self.bus = bus
        self.clk = clk
        self._idle_bus()

    def _idle_bus(self) -> None:
        """Drive bus to idle defaults."""
        self.bus.psel.value = 0
        self.bus.penable.value = 0
        self.bus.pwrite.value = 0
        self.bus.paddr.value = 0
        self.bus.pwdata.value = 0

    async def reset(self) -> None:
        """Return the bus to idle on the next rising clock edge."""
        await RisingEdge(self.clk)
        self._idle_bus()
        await ReadOnly()

    async def write(self, addr: int, data: int) -> None:
        """Perform an APB write transaction."""
        await self._transfer(addr=addr, data=data, write=True)

    async def read(self, addr: int) -> ApbResponse:
        """Perform an APB read transaction and return the response."""
        return await self._transfer(addr=addr, data=0, write=False)

    async def _transfer(self, addr: int, data: int, write: bool) -> ApbResponse:
        """Common transfer engine for read and write operations."""
        self.bus.paddr.value = addr
        self.bus.pwrite.value = int(write)
        self.bus.pwdata.value = data
        self.bus.psel.value = 1
        self.bus.penable.value = 0
        self._log.debug("APB %s addr=0x%03x data=0x%08x", "WRITE" if write else "READ", addr, data)

        await RisingEdge(self.clk)
        self.bus.penable.value = 1

        # Wait for PREADY while allowing slaves to deassert it for multiple cycles.
        while True:
            await ReadOnly()
            if int(self.bus.pready.value) == 1:
                break
            await RisingEdge(self.clk)

        resp = ApbResponse(data=int(self.bus.prdata.value), slverr=int(self.bus.pslverr.value))
        self._log.debug("  -> ready data=0x%08x slverr=%d", resp.data, resp.slverr)

        # Return to idle.
        self.bus.psel.value = 0
        self.bus.penable.value = 0
        self.bus.pwrite.value = 0
        self.bus.paddr.value = 0
        self.bus.pwdata.value = 0

        await RisingEdge(self.clk)
        return resp


def decode_status(value: int) -> dict[str, int]:
    """Helper to interpret aon_power_ctrl status register fields."""
    return {
        "pst_state": value & 0xF,
        "wake_irq": (value >> 8) & 0x1,
    }
