#!/usr/bin/env python3
"""Preflight checks for the optional full-UVM Verilator lane."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BUILD_ROOT = ROOT / "build" / "uvm_env_check"


def find_uvm_pkg(uvm_home: Path) -> Path | None:
    for candidate in (uvm_home / "uvm_pkg.sv", uvm_home / "src" / "uvm_pkg.sv"):
        if candidate.exists():
            return candidate
    return None


def fail(message: str) -> int:
    print(f"UVM environment check failed: {message}", file=sys.stderr)
    print(
        "Set VERILATOR_UVM to a UVM-capable Verilator executable and UVM_HOME "
        "to an extracted UVM 2017/IEEE 1800.2 source tree. The local Debian "
        "Verilator 5.020 is not expected to run this optional lane.",
        file=sys.stderr,
    )
    return 2


def main() -> int:
    verilator = os.environ.get("VERILATOR_UVM", "")
    uvm_home_raw = os.environ.get("UVM_HOME", "")
    if not verilator:
        return fail("VERILATOR_UVM is not set")
    if not Path(verilator).exists() and "/" in verilator:
        return fail(f"VERILATOR_UVM does not exist: {verilator}")
    if not uvm_home_raw:
        return fail("UVM_HOME is not set")

    uvm_home = Path(uvm_home_raw).expanduser().resolve()
    if not uvm_home.exists():
        return fail(f"UVM_HOME does not exist: {uvm_home}")

    uvm_pkg = find_uvm_pkg(uvm_home)
    if uvm_pkg is None:
        return fail(f"Could not find uvm_pkg.sv under {uvm_home} or {uvm_home / 'src'}")

    version = subprocess.run([verilator, "--version"], capture_output=True, text=True)
    if version.returncode != 0:
        return fail(f"Could not run {verilator} --version")

    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    obj_dir = BUILD_ROOT / "obj_dir"
    if obj_dir.exists():
        shutil.rmtree(obj_dir)
    smoke = BUILD_ROOT / "uvm_env_smoke.sv"
    smoke.write_text(
        "module uvm_env_smoke;\n"
        "  import uvm_pkg::*;\n"
        "  `include \"uvm_macros.svh\"\n"
        "  initial begin\n"
        "    `uvm_info(\"UVMENV\", \"minimal UVM compile smoke\", UVM_LOW)\n"
        "    $finish;\n"
        "  end\n"
        "endmodule\n"
    )

    cmd = [
        verilator,
        "--binary",
        "-j",
        os.environ.get("UVM_BUILD_JOBS", str(os.cpu_count() or 1)),
        "--sv",
        "--timing",
        "-Wno-fatal",
        "+define+UVM_NO_DPI",
        f"+incdir+{uvm_pkg.parent}",
        str(uvm_pkg),
        str(smoke),
        "--top-module",
        "uvm_env_smoke",
        "-Mdir",
        str(obj_dir),
    ]
    result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    (BUILD_ROOT / "uvm_env_smoke.compile.log").write_text(
        "## compile_cmd\n"
        + " ".join(cmd)
        + "\n\n## stdout\n"
        + result.stdout
        + "\n## stderr\n"
        + result.stderr
    )
    if result.returncode != 0:
        return fail(f"minimal UVM compile smoke failed; see {BUILD_ROOT / 'uvm_env_smoke.compile.log'}")

    print("UVM environment check passed:")
    print(f"  - VERILATOR_UVM={verilator}")
    print(f"  - {version.stdout.strip() or version.stderr.strip()}")
    print(f"  - UVM package={uvm_pkg}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
