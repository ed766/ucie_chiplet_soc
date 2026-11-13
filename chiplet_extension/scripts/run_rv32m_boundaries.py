#!/usr/bin/env python3
"""Execute and independently replay a fixed core-boundary matrix."""
import csv
import argparse
import hashlib
import os
import re
import subprocess
from pathlib import Path

from rv32_iss import RV32ISS

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
BUILD = ROOT / "build/rv32m_boundaries"


def boundary_witness(knobs, trace, output):
    """Require executed retirement and phase witnesses, not requested plusargs."""
    with trace.open() as handle:
        records = list(csv.DictReader(handle))
    m_records = [r for r in records if (int(r['insn'], 16) & 0xfe00007f) == 0x02000033]
    matching = [r for r in m_records if ((int(r['insn'], 16) >> 12) & 7) == knobs['op']]
    if not matching:
        return False, ''
    mode = knobs['mode']
    events = []
    for match in re.finditer(r'BOUNDARY_EVENT\|([^|\n]+)\|([^\n]+)', output):
        fields = dict(part.split('=', 1) for part in match[2].split('|') if '=' in part)
        events.append((match[1], fields))
    if mode == 'disabled':
        matching = [r for r in matching if r['trap'] == '1' and int(r['mcause'], 16) == 2]
    elif mode == 'irq':
        arrivals = [v for e, v in events if e == 'irq_arrival']
        expected_busy = int(knobs['phase'] in (1, 2))
        if len(arrivals) != 1 or int(arrivals[0]['busy']) != expected_busy:
            return False, 'irq_arrival_phase_not_reached'
        if int(arrivals[0]['result']) != int(knobs['phase'] == 2):
            return False, 'irq_result_phase_not_reached'
        cause = 0x80000007 if knobs['source'] == 1 else 0x8000000b
        if not any(r['intr'] == '1' and int(r['mcause'], 16) == cause for r in records):
            return False, 'irq_entry_not_reached'
    elif mode == 'reset':
        targets = [v for e, v in events if e == 'reset_target']
        if len(targets) != 1 or len({r['epoch'] for r in records}) != 2:
            return False, 'reset_epoch_not_reached'
        phase = knobs['phase']; target = targets[0]
        if int(target['busy']) != int(phase > 0) or int(target['result']) != int(phase == 5):
            return False, 'reset_busy_phase_not_reached'
        if phase == 3 and int(target['iteration']) != 31:
            return False, 'reset_final_iteration_not_reached'
        if phase in (1, 2) and int(target['iteration']) != (1 if phase == 1 else 16):
            return False, 'reset_iteration_not_reached'
        if phase == 4 and int(target['state']) != 2:
            return False, 'reset_finalization_not_reached'
    elif mode == 'apb':
        if not any(int(r['mem_rmask'], 16) for r in records) or not any(int(r['mem_wmask'], 16) for r in records):
            return False, 'load_store_chain_not_reached'
    evidence = ';'.join(f"epoch:{r['epoch']}/order:{r['order']}/cycle:{r['cycle']}" for r in matching)
    return bool(matching), evidence


def cases():
    for phase in range(8):
        yield dict(mode="fault", op=0, phase=phase)
    for op in range(8):
        yield dict(mode="disabled", op=op)
        for alias in range(4):
            yield dict(mode="alias", op=op, alias=alias)
        for phase in range(6):
            yield dict(mode="reset", op=op, phase=phase)
        for source in range(3):
            for phase in range(4):
                for masked in range(2):
                    yield dict(mode="irq", op=op, source=source, phase=phase, masked=masked)
        for waits in (0, 1, 4):
            yield dict(mode="apb", op=op, waits=waits)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--code-coverage', action='store_true')
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    sources = [REPO/'base_soc/rtl/pd1_rv32'/name for name in ('rv32_core.sv','rv32_muldiv.sv')]
    sources.extend((ROOT/'sim/tb_rv32m_boundaries.sv', Path(__file__)))
    source_hash = hashlib.sha256(b''.join(p.read_bytes() for p in sources)).hexdigest()
    checker_hash = hashlib.sha256((ROOT/'scripts/rv32_iss.py').read_bytes()).hexdigest()
    tool = subprocess.check_output(['verilator', '--version'], text=True).strip()
    binaries = {}
    for enabled in (0, 1):
        obj = BUILD / f"obj_{enabled}{'_cov' if args.code_coverage else ''}"
        cmd = ["verilator", "--timing", "--assert", "-Wall", "-Wno-fatal",
               "-Wno-PINMISSING", "-Wno-WIDTH", "-Wno-UNUSEDSIGNAL", "-Wno-BLKSEQ",
               f"-GENABLE_M={enabled}", "--top-module", "tb_rv32m_boundaries", "-Mdir", str(obj),
               str(REPO / "base_soc/rtl/pd1_rv32/rv32_muldiv.sv"),
               str(REPO / "base_soc/rtl/pd1_rv32/rv32_core.sv"),
               str(ROOT / "sim/tb_rv32m_boundaries.sv")]
        cmd.extend(["--cc", "--exe", "--build", "--coverage", str(ROOT / "sim/rv32m_coverage_main.cpp")]
                   if args.code_coverage else ["--binary"])
        result = subprocess.run(cmd, capture_output=True, text=True)
        (BUILD / f"compile_{enabled}.log").write_text(result.stdout + result.stderr)
        if result.returncode:
            raise SystemExit(f"boundary compile failed: build/rv32m_boundaries/compile_{enabled}.log")
        binaries[enabled] = obj / "Vtb_rv32m_boundaries"
    rows = []
    for knobs in cases():
        name = "__".join(f"{key}_{value}" for key, value in knobs.items())
        trace = BUILD / f"{name}.csv"
        cmd = [str(binaries[int(knobs['mode'] != 'disabled')]), f"+TRACE={trace}"]
        cmd.extend(f"+{key.upper()}={value}" for key, value in knobs.items())
        env = os.environ.copy()
        env['VERILATOR_COVERAGE_FILE'] = str(BUILD / f"{name}.dat")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20, env=env)
        (BUILD / f"{name}.log").write_text(result.stdout + result.stderr)
        checked = RV32ISS(enable_m=knobs["mode"] != "disabled").check(trace) if trace.exists() else None
        witnessed, evidence = boundary_witness(knobs, trace, result.stdout) if trace.exists() else (False, 'missing_trace')
        passed = (result.returncode == 0 and "RV32M_BOUNDARY|status=PASS" in result.stdout and witnessed and
                  checked is not None and checked.instructions > 0 and not checked.mismatches)
        rows.append(dict(test=name, status="PASS" if passed else "FAIL", **knobs,
                         rtl_status="PASS" if result.returncode == 0 else "FAIL",
                         iss_status="PASS" if checked and not checked.mismatches else "FAIL",
                         retirements=checked.instructions if checked else 0,
                         stimulus_reached=int(witnessed), witness=evidence,
                         source_sha256=source_hash, simulator=tool,
                         checker_sha256=checker_hash,
                         first_mismatch=checked.mismatches[0] if checked and checked.mismatches else "",
                         trace=str(trace.relative_to(REPO)), trace_sha256=hashlib.sha256(trace.read_bytes()).hexdigest() if trace.exists() else ''))
        if not passed:
            print(f"FAIL {name}: {rows[-1]['first_mismatch']}\n{result.stdout[-2000:]}{result.stderr[-1000:]}", flush=True)
    fields = sorted({key for row in rows for key in row})
    report = ROOT / "reports/rv32m_boundary_summary.csv"
    with report.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"RV32M core boundaries: {passed} / {len(rows)} PASS")
    if args.code_coverage:
        unit_obj = BUILD / 'unit_cov'
        unit_cmd = ['verilator','--cc','--exe','--build','--coverage','--assert','--timing',
                    '-Wno-fatal','--top-module','tb_rv32_muldiv','-Mdir',str(unit_obj),
                    '-CFLAGS','-DRV32M_COVERAGE_UNIT',str(sources[1]),
                    str(ROOT/'sim/tb_rv32_muldiv.sv'),str(ROOT/'sim/rv32m_coverage_main.cpp')]
        compiled = subprocess.run(unit_cmd, capture_output=True, text=True)
        (BUILD/'unit_cov_compile.log').write_text(compiled.stdout+compiled.stderr)
        if compiled.returncode:
            raise SystemExit('unit coverage compile failed')
        env = os.environ.copy();env['VERILATOR_COVERAGE_FILE']=str(BUILD/'unit.dat')
        result = subprocess.run([str(unit_obj/'Vtb_rv32_muldiv')],env=env,capture_output=True,text=True,timeout=20)
        (BUILD/'unit_cov_run.log').write_text(result.stdout+result.stderr)
        if result.returncode or 'RV32M_SUMMARY|72|72|PASS' not in result.stdout:
            raise SystemExit('unit coverage nominal control failed')
        summarize_coverage(rows)
    return int(passed != len(rows))


def summarize_coverage(rows):
    """Native point counts, with disabled and enabled geometries kept separate."""
    points = {}
    for row in [*rows, dict(status='PASS', mode='unit', test='unit')]:
        if row['status'] != 'PASS':
            continue
        variant = 'rv32i_disabled_m' if row['mode'] == 'disabled' else 'rv32im_enabled_m'
        database = BUILD / f"{row['test']}.dat"
        if not database.exists():
            raise SystemExit(f'missing coverage database: {database}')
        for record in database.read_text().splitlines():
            if not record.startswith("C '"):
                continue
            end = record.rfind("'")
            meta = dict(part.split('\x02', 1) for part in record[3:end].split('\x01') if '\x02' in part)
            name = Path(meta.get('f', '')).name
            if name not in ('rv32_core.sv', 'rv32_muldiv.sv'):
                continue
            kind = meta.get('page', '').split('/')[0]
            key = variant, name, kind, meta.get('l', ''), meta.get('o', ''), meta.get('n', '')
            points[key] = points.get(key, 0) + int(record[end+1:].strip())
    summary = []
    for variant in ('rv32i_disabled_m', 'rv32im_enabled_m'):
        for name in ('rv32_core.sv', 'rv32_muldiv.sv'):
            for kind in ('v_line', 'v_branch', 'v_toggle'):
                selected = [count for key, count in points.items() if key[:3] == (variant, name, kind)]
                hits = sum(count > 0 for count in selected)
                summary.append(dict(variant=variant, file=name, point_type=kind,
                    hit=hits, total=len(selected), raw_percent=f'{100*hits/len(selected):.2f}' if selected else 'NA',
                    instrumentation_status='AVAILABLE' if selected else 'UNAVAILABLE', exclusions=0))
    with (ROOT/'reports/rv32m_boundary_code_coverage.csv').open('w', newline='') as handle:
        writer=csv.DictWriter(handle, fieldnames=list(summary[0]), lineterminator='\n')
        writer.writeheader();writer.writerows(summary)
    with (ROOT/'reports/rv32m_boundary_coverage_holes.csv').open('w', newline='') as handle:
        writer=csv.writer(handle, lineterminator='\n');writer.writerow(('variant','file','point_type','line','object','column','hit_count'))
        writer.writerows((*key, count) for key, count in sorted(points.items()) if not count)


if __name__ == '__main__':
    raise SystemExit(main())
