#!/usr/bin/env python3
"""Generate ACT4 tests and execute each self-checking ELF on the RTL core."""

from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
from pathlib import Path

from build_compiled_firmware import binary_to_relocated_rom_hex
from run_compiled_firmware import compile_sim, parse_result
from rv32_toolchain import tool

ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "reports" / "rv32_act_summary.csv"
REVISION = "a7c99303516f4e668f7488f172043392e23b9dfd"
ACT_RESULT_RE = re.compile(r"ACT4_RESULT\|(?P<fields>[^\n]+)")


def parse_act_result(text: str) -> dict[str, str]:
    match = ACT_RESULT_RE.search(text)
    return {} if not match else dict(item.split("=", 1) for item in match.group("fields").split("|") if "=" in item)


def words(path: Path) -> list[str]:
    data = path.read_bytes()
    if len(data) % 4:
        data += bytes(4 - len(data) % 4)
    return [f"{int.from_bytes(data[index:index + 4], 'little'):08x}"
            for index in range(0, len(data), 4)]


def section_address(objdump: str, elf: Path, name: str) -> int:
    """Read a section VMA from objdump's stable, whitespace-delimited table."""
    result = subprocess.run([objdump, "-h", str(elf)], check=True, capture_output=True, text=True)
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[1] == name:
            return int(fields[3], 16)
    raise RuntimeError(f"ELF has no {name} section: {elf}")


def write_harvard_data_image(text: Path, text_base: int, data: Path, output: Path) -> None:
    """Mirror ACT's unified image through the core's SRAM alias mapping."""
    lines = [f"@{text_base // 4:08x}", *words(text), "@0001e000", *words(data)]
    output.write_text("\n".join(lines) + "\n")


def prepare_config(home: Path, work: Path) -> Path:
    """Create a self-contained ACT config from project inputs and pinned Sail data."""
    source = ROOT / "verification" / "act4"
    config_dir = work / "dut_config"
    config_dir.mkdir(parents=True)
    for name in ("test_config.yaml", "ucie-chiplet-rv32i.yaml", "link.ld",
                 "rvmodel_macros.h", "rvtest_config.h", "rvtest_config.svh"):
        shutil.copy2(source / name, config_dir / name)

    sail_template = home / "config" / "sail" / "sail-RVI20U32" / "sail.json"
    sail_text = sail_template.read_text()
    # Expand the template's first region into the RTL's 0-based executable RAM
    # and move its device window upward. Keep regions monotonically ordered as
    # required by Sail's configuration validator.
    sail_text = sail_text.replace(
        '"base": {\n          "len": 64,\n          "value": "0x1000"',
        '"base": {\n          "len": 64,\n          "value": "0x0"', 1)
    sail_text = sail_text.replace(
        '"size": {\n          "len": 64,\n          "value": "0x1000"',
        '"size": {\n          "len": 64,\n          "value": "0x40000000"', 1)
    sail_text = sail_text.replace('"executable": false', '"executable": true', 1)
    sail_text = sail_text.replace('"writable": false', '"writable": true', 1)
    sail_text = sail_text.replace(
        '"base": {\n          "len": 64,\n          "value": "0x2000000"',
        '"base": {\n          "len": 64,\n          "value": "0x60000000"', 1)
    (config_dir / "sail.json").write_text(sail_text)
    return config_dir / "test_config.yaml"


def execute_elfs(elfs: list[Path], verilator: str, work: Path,
                 mutation: str | None = None) -> list[dict[str, object]]:
    """Convert ACT4 ELFs to the core's split ROM/SRAM images and run them."""
    binary = compile_sim(verilator, False, variant_tag="act4", extra_defines=("ACT4_MODE",),
                         mutation_define=mutation)
    objcopy = tool("objcopy")
    objdump = tool("objdump")
    image_dir = work / "rtl_images"
    image_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for index, elf in enumerate(sorted(elfs)):
        stem = f"act4_{index:04d}_{elf.stem}"
        text_bin = image_dir / f"{stem}.text.bin"
        data_bin = image_dir / f"{stem}.data.bin"
        text_hex = image_dir / f"{stem}.hex"
        data_hex = image_dir / f"{stem}.data.hex"
        subprocess.run([objcopy, "-O", "binary", "--only-section=.text",
                        str(elf), str(text_bin)], check=True)
        # ACT tests use a unified-memory programming model and may read literal
        # data from executable sections. Mirror text and data into the Harvard
        # SRAM, translating the high data VMA through MAILBOX_ALIAS_BASE=0x8000.
        subprocess.run([objcopy, "-O", "binary", "--only-section=.data",
                        str(elf), str(data_bin)], check=True)
        text_base = section_address(objdump, elf, ".text")
        binary_to_relocated_rom_hex(text_bin, text_hex, text_base)
        write_harvard_data_image(text_bin, text_base, data_bin, data_hex)
        coverage_csv = work / f"{stem}.coverage.csv"
        rvfi_trace = work / f"{stem}.rvfi.csv"
        command = [str(binary), "+TEST=act4", f"+FIRMWARE_HEX={text_hex}",
                   f"+DATA_HEX={data_hex}", f"+COVER_OUT={coverage_csv}",
                   f"+RVFI_TRACE_OUT={rvfi_trace}"]
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            parsed = parse_result(output)
            act_result = parse_act_result(output)
            status = "PASS" if result.returncode == 0 and parsed.get("status") == "PASS" else "FAIL"
            failure_kind = "" if status == "PASS" else act_result.get("kind", "rtl_failure")
            detail = "self_checking_mailbox_pass" if status == "PASS" else failure_kind
            (work / f"{stem}.log").write_text(output)
        except subprocess.TimeoutExpired as exc:
            status, detail, failure_kind, act_result = "FAIL", "host_timeout", "host_timeout", {}
            text = (exc.stdout or "") + (exc.stderr or "")
            (work / f"{stem}.log").write_text(text)
        rows.append({"suite": elf.stem, "status": status, "applicable_tests": 1,
                     "detail": detail, "failure_kind": failure_kind,
                     "mailbox_status": act_result.get("mailbox", ""),
                     "failing_address": act_result.get("last_pc", ""),
                     "register": "NA", "expected": "PASS_MAILBOX=00000001",
                     "observed": act_result.get("mailbox", ""),
                     "trace": str(rvfi_trace.relative_to(ROOT.parent))})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true")
    parser.add_argument("--verilator", default="verilator")
    parser.add_argument("--suite-prefix")
    parser.add_argument("--mutation")
    parser.add_argument("--expect-detection", action="store_true")
    parser.add_argument("--report", type=Path, default=REPORT)
    args = parser.parse_args()
    home_text = os.environ.get("RISCV_ACT_HOME", "")
    sail = shutil.which("sail_riscv_sim")
    rows: list[dict[str, object]] = []
    if home_text and Path(home_text).exists() and sail:
        home = Path(home_text)
        revision = subprocess.run(["git", "-C", str(home), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        if revision != REVISION:
            rows.append({"suite": "ACT4_RV32I_Zicsr", "status": "FAIL",
                         "applicable_tests": 0, "detail": f"revision_mismatch:{revision}",
                         "failure_kind": "revision_mismatch", "mailbox_status": "",
                         "failing_address": "", "register": "NA", "expected": REVISION,
                         "observed": revision, "trace": ""})
        else:
            work = ROOT / "build" / "act4"
            shutil.rmtree(work, ignore_errors=True)
            work.mkdir(parents=True, exist_ok=True)
            config = prepare_config(home, work)
            result = subprocess.run(["make", "-j2", f"CONFIG_FILES={config}", f"WORKDIR={work}"], cwd=home,
                                    capture_output=True, text=True)
            (work / "act4.log").write_text(result.stdout + result.stderr)
            # ACT also leaves reference-signature intermediate ELFs under
            # build/. Execute only the final self-checking images under elfs/.
            elfs = [path for path in work.rglob("*.elf") if "elfs" in path.parts]
            if args.suite_prefix:
                elfs = [path for path in elfs if path.stem.startswith(args.suite_prefix)]
            if result.returncode == 0 and elfs:
                try:
                    rows = execute_elfs(elfs, args.verilator, work, args.mutation)
                except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
                    rows = [{"suite": "ACT4_RV32I_Zicsr", "status": "FAIL",
                             "applicable_tests": len(elfs), "detail": f"rtl_execution_setup_failed:{exc}",
                             "failure_kind": "setup", "mailbox_status": "", "failing_address": "",
                             "register": "NA", "expected": "runnable_elf", "observed": str(exc), "trace": ""}]
            else:
                rows.append({"suite": "ACT4_RV32I_Zicsr", "status": "FAIL",
                             "applicable_tests": len(elfs), "detail": "generation_failed",
                             "failure_kind": "generation", "mailbox_status": "", "failing_address": "",
                             "register": "NA", "expected": "generated_elf", "observed": "none", "trace": ""})
    else:
        rows.append({"suite": "ACT4_RV32I_Zicsr", "status": "SKIP",
                     "applicable_tests": 0, "detail": "RISCV_ACT_HOME_or_Sail_missing",
                     "failure_kind": "dependency_missing", "mailbox_status": "", "failing_address": "",
                     "register": "NA", "expected": "pinned_dependencies", "observed": "missing", "trace": ""})
    args.report.parent.mkdir(exist_ok=True)
    with args.report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=("suite", "status", "applicable_tests", "detail",
                                                      "failure_kind", "mailbox_status", "failing_address",
                                                      "register", "expected", "observed", "trace"), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    skipped = sum(row["status"] == "SKIP" for row in rows)
    failed = sum(row["status"] == "FAIL" for row in rows)
    print(f"ACT4 RTL: {passed} PASS, {skipped} SKIP, {failed} FAIL")
    if args.expect_detection:
        return 0 if failed else 1
    return 1 if failed or (args.require and passed != len(rows)) else 0


if __name__ == "__main__": raise SystemExit(main())
