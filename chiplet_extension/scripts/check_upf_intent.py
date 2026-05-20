#!/usr/bin/env python3
"""Static checks for the chiplet UPF package.

This is not a UPF-aware signoff parser. It validates that the repo-local
tool-neutral UPF intent contains the expected domains, switches, isolation,
retention strategies, PST states, and RTL hierarchy/control references.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
UPF = ROOT / "upf" / "chiplet_full.upf"
TOP = ROOT / "rtl" / "soc_chiplet_top.sv"
DIE_A = ROOT / "rtl" / "soc_die_a_top.sv"
DIE_B = ROOT / "rtl" / "soc_die_b_top.sv"
PWR_CTRL = ROOT / "rtl" / "power" / "chiplet_power_ctrl.sv"

DOMAINS = [
    "AON_CHIPLET",
    "PD_A_TRAFFIC",
    "PD_A_DMA",
    "PD_A_LINK",
    "PD_B_CRYPTO",
    "PD_B_LINK",
    "PD_CHANNEL",
]

SWITCHABLE = [
    "PD_A_TRAFFIC",
    "PD_A_DMA",
    "PD_A_LINK",
    "PD_B_CRYPTO",
    "PD_B_LINK",
    "PD_CHANNEL",
]

POWER_SWITCHES = {
    "PD_A_TRAFFIC": "PS_PD_A_TRAFFIC",
    "PD_A_DMA": "PS_PD_A_DMA",
    "PD_A_LINK": "PS_PD_A_LINK",
    "PD_B_CRYPTO": "PS_PD_B_CRYPTO",
    "PD_B_LINK": "PS_PD_B_LINK",
    "PD_CHANNEL": "PS_PD_CHANNEL",
}

ISOLATION = {
    "PD_A_TRAFFIC": "ISO_PD_A_TRAFFIC",
    "PD_A_DMA": "ISO_PD_A_DMA",
    "PD_A_LINK": "ISO_PD_A_LINK",
    "PD_B_CRYPTO": "ISO_PD_B_CRYPTO",
    "PD_B_LINK": "ISO_PD_B_LINK",
    "PD_CHANNEL": "ISO_PD_CHANNEL",
}

PST = {
    "RUN": {
        "AON_CHIPLET": "ON",
        "PD_A_TRAFFIC": "ON",
        "PD_A_DMA": "ON",
        "PD_A_LINK": "ON",
        "PD_B_CRYPTO": "ON",
        "PD_B_LINK": "ON",
        "PD_CHANNEL": "ON",
    },
    "CRYPTO_ONLY": {
        "AON_CHIPLET": "ON",
        "PD_A_TRAFFIC": "OFF",
        "PD_A_DMA": "ON",
        "PD_A_LINK": "ON",
        "PD_B_CRYPTO": "ON",
        "PD_B_LINK": "ON",
        "PD_CHANNEL": "ON",
    },
    "SLEEP": {
        "AON_CHIPLET": "ON",
        "PD_A_TRAFFIC": "OFF",
        "PD_A_DMA": "RETAIN",
        "PD_A_LINK": "OFF",
        "PD_B_CRYPTO": "OFF",
        "PD_B_LINK": "OFF",
        "PD_CHANNEL": "OFF",
    },
    "DEEP_SLEEP": {
        "AON_CHIPLET": "ON",
        "PD_A_TRAFFIC": "OFF",
        "PD_A_DMA": "OFF",
        "PD_A_LINK": "OFF",
        "PD_B_CRYPTO": "OFF",
        "PD_B_LINK": "OFF",
        "PD_CHANNEL": "OFF",
    },
}

EXPECTED_SIGNALS = [
    "sw_pd_a_traffic",
    "sw_pd_a_dma",
    "sw_pd_a_link",
    "sw_pd_b_crypto",
    "sw_pd_b_link",
    "sw_pd_channel",
    "iso_pd_a_traffic_n",
    "iso_pd_a_dma_n",
    "iso_pd_a_link_n",
    "iso_pd_b_crypto_n",
    "iso_pd_b_link_n",
    "iso_pd_channel_n",
    "save_dma_sleep",
    "restore_dma_sleep",
    "save_dma_mem",
    "restore_dma_mem",
]

EXPECTED_HIERARCHY = [
    "soc_chiplet_top/u_pwr_ctrl",
    "soc_chiplet_top/u_die_a/u_die_a_system",
    "soc_chiplet_top/u_die_a/u_dma",
    "soc_chiplet_top/u_die_a/u_packetizer",
    "soc_chiplet_top/u_die_a/u_depacketizer",
    "soc_chiplet_top/u_die_a/u_credit_mgr",
    "soc_chiplet_top/u_die_a/u_link_fsm",
    "soc_chiplet_top/u_die_a/u_retry_ctrl",
    "soc_chiplet_top/u_die_a/u_tx",
    "soc_chiplet_top/u_die_a/u_rx",
    "soc_chiplet_top/u_die_a/u_phy",
    "soc_chiplet_top/u_die_b/u_die_b_system",
    "soc_chiplet_top/u_die_b/u_packetizer",
    "soc_chiplet_top/u_die_b/u_depacketizer",
    "soc_chiplet_top/u_die_b/u_credit_mgr",
    "soc_chiplet_top/u_die_b/u_link_fsm",
    "soc_chiplet_top/u_die_b/u_retry_ctrl",
    "soc_chiplet_top/u_die_b/u_tx",
    "soc_chiplet_top/u_die_b/u_rx",
    "soc_chiplet_top/u_die_b/u_phy",
    "soc_chiplet_top/u_channel",
]


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing required file: {path.relative_to(REPO)}")
        return ""


errors: list[str] = []


def fail(msg: str) -> None:
    errors.append(msg)


def require(pattern: str, text: str, msg: str, flags: int = 0) -> None:
    if re.search(pattern, text, flags) is None:
        fail(msg)


def check_pst(upf: str) -> None:
    for state, values in PST.items():
        match = re.search(
            rf"add_pst_state\s+CHIPLET_PST\s+{state}\s+\\\s*"
            rf"-domain_state\s+\{{([^}}]+)\}}",
            upf,
            re.MULTILINE | re.DOTALL,
        )
        if not match:
            fail(f"missing PST state {state}")
            continue
        tokens = match.group(1).split()
        seen = dict(zip(tokens[0::2], tokens[1::2]))
        for domain, expected in values.items():
            actual = seen.get(domain)
            if actual != expected:
                fail(f"PST {state} has {domain}={actual}, expected {expected}")


def instance_exists(path: str, top: str, die_a: str, die_b: str) -> bool:
    parts = path.split("/")
    if parts[0] != "soc_chiplet_top":
        return False
    if len(parts) == 2:
        return re.search(rf"\b{re.escape(parts[1])}\b", top) is not None
    if parts[1] == "u_die_a" and len(parts) == 3:
        return (
            re.search(r"\bu_die_a\b", top) is not None
            and re.search(rf"\b{re.escape(parts[2])}\b", die_a) is not None
        )
    if parts[1] == "u_die_b" and len(parts) == 3:
        return (
            re.search(r"\bu_die_b\b", top) is not None
            and re.search(rf"\b{re.escape(parts[2])}\b", die_b) is not None
        )
    return False


def main() -> int:
    upf = read(UPF)
    top = read(TOP)
    die_a = read(DIE_A)
    die_b = read(DIE_B)
    pwr_ctrl = read(PWR_CTRL)

    require(r"set_power_intent\s+-upf_version\s+4\.0", upf, "UPF version 4.0 is not declared")

    for domain in DOMAINS:
        require(rf"create_power_domain\s+{domain}\b", upf, f"missing power domain {domain}")

    for domain in SWITCHABLE:
        switch = POWER_SWITCHES[domain]
        require(
            rf"create_power_switch\s+{switch}\b.*?-domain\s+{domain}\b",
            upf,
            f"missing power switch {switch} for {domain}",
            re.DOTALL,
        )
        iso = ISOLATION[domain]
        require(
            rf"set_isolation\s+{iso}\b.*?-domain\s+{domain}\b.*?-applies_to\s+outputs",
            upf,
            f"missing output isolation {iso} for {domain}",
            re.DOTALL,
        )

    for retention in ["RET_DMA_SLEEP_CTX", "RET_DMA_MEM_BANKS"]:
        require(rf"set_retention\s+{retention}\b", upf, f"missing retention strategy {retention}")
        require(
            rf"set_retention_control\s+{retention}\b",
            upf,
            f"missing retention controls for {retention}",
        )

    require(r"create_power_state_table\s+CHIPLET_PST\b", upf, "missing CHIPLET_PST")
    check_pst(upf)

    require(r"chiplet_power_ctrl\s+u_pwr_ctrl\b", top, "soc_chiplet_top does not instantiate u_pwr_ctrl")
    for signal in EXPECTED_SIGNALS:
        if signal not in pwr_ctrl:
            fail(f"chiplet_power_ctrl missing signal {signal}")
        if f"u_pwr_ctrl/{signal}" not in upf:
            fail(f"UPF does not reference u_pwr_ctrl/{signal}")

    for path in EXPECTED_HIERARCHY:
        if path not in upf:
            fail(f"UPF does not reference hierarchy path {path}")
        if not instance_exists(path, top, die_a, die_b):
            fail(f"RTL hierarchy path not found: {path}")

    if errors:
        print("UPF intent check FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("UPF intent check passed:")
    print(f"  - {UPF.relative_to(REPO)} declares UPF 4.0")
    print(f"  - {len(DOMAINS)} domains, {len(SWITCHABLE)} switches/isolation strategies")
    print("  - DMA sleep-context and memory-bank retention strategies found")
    print("  - RUN/CRYPTO_ONLY/SLEEP/DEEP_SLEEP PST values match expected policy")
    print("  - UPF hierarchy/control references are present in RTL source")
    return 0


if __name__ == "__main__":
    sys.exit(main())
