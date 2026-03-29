#!/usr/bin/env python3
import argparse
import csv
from datetime import datetime
from pathlib import Path


def read_key_value_csv(path: Path) -> dict[str, str]:
    data = {}
    try:
        with path.open() as f:
            for row in csv.reader(f):
                if not row:
                    continue
                if len(row) >= 2:
                    data[str(row[0]).strip()] = str(row[1]).strip()
    except FileNotFoundError:
        pass
    return data


def parse_timing(path: Path) -> dict[str, float]:
    kv = read_key_value_csv(path)
    out = {}
    if 'wns_ns' in kv:
        try:
            out['wns_ns'] = float(kv['wns_ns'])
        except Exception:
            pass
    if 'fmax_mhz' in kv and kv['fmax_mhz'] not in ('NA', ''):
        try:
            out['fmax_mhz'] = float(kv['fmax_mhz'])
        except Exception:
            pass
    return out


def parse_area(path: Path) -> dict[str, float]:
    # area/overhead.csv may contain tokens like:
    #  cell_overhead,iso:100,ret:32,area_um2,1200
    out: dict[str, float] = {}
    try:
        with path.open() as f:
            row = next(csv.reader(f))
            tokens = [t.strip() for t in row if t.strip()]
            i = 0
            while i < len(tokens):
                tok = tokens[i]
                if ':' in tok:
                    k, v = tok.split(':', 1)
                    try:
                        out[k] = float(v)
                    except Exception:
                        pass
                    i += 1
                else:
                    # Expect a key followed by a value token
                    k = tok
                    v = tokens[i + 1] if i + 1 < len(tokens) else ''
                    if k == 'area_um2':
                        try:
                            out[k] = float(v)
                        except Exception:
                            pass
                    # ignore other free-form keys (like 'cell_overhead')
                    i += 2
    except Exception:
        pass
    return out


def parse_power_leakage(path: Path) -> dict[str, float]:
    # Expect columns: corner,mode,leakage_mW,save_percent
    results = {}
    try:
        with path.open() as f:
            rdr = csv.DictReader(f)
            for row in rdr:
                corner = row.get('corner', '')
                mode = row.get('mode', '')
                leak = row.get('leakage_mW', '')
                key = f"leak_{corner}_{mode}"
                try:
                    results[key] = float(leak)
                except Exception:
                    continue
    except Exception:
        pass
    return results


def append_history(history_file: Path, fields: list[str], values: dict[str, float]):
    history_file.parent.mkdir(parents=True, exist_ok=True)
    now = datetime.utcnow().isoformat(timespec='seconds') + 'Z'
    row = {'timestamp': now}
    for k in fields:
        row[k] = values.get(k, '')

    # Read last row for deltas
    prev = None
    if history_file.exists():
        with history_file.open() as f:
            rows = list(csv.DictReader(f))
            if rows:
                prev = rows[-1]

    # Prepare header with delta columns
    header = ['timestamp'] + fields + [f"delta_{k}" for k in fields]

    # Compute deltas
    for k in fields:
        dv = ''
        if prev is not None:
            try:
                pv = float(prev.get(k, ''))
                cv = float(values.get(k, ''))
                dv = cv - pv
            except Exception:
                dv = ''
        row[f"delta_{k}"] = dv

    # Write out
    write_header = not history_file.exists()
    with history_file.open('a', newline='') as f:
        w = csv.DictWriter(f, fieldnames=header)
        if write_header:
            w.writeheader()
        w.writerow(row)

    return row  # include deltas


def update_summary(summary_path: Path, deltas: dict[str, float]):
    # Append or update key/value lines
    lines = []
    if summary_path.exists():
        lines = summary_path.read_text().splitlines()
    existing = dict(
        (l.split(',')[0], l.split(',')[1])
        for l in lines if ',' in l
    )
    for k, v in deltas.items():
        existing[k] = str(v)
    # Re-emit in a stable order
    order = [
        # Only delta keys here; header handled separately
        'delta_wns_ns', 'delta_fmax_mhz', 'delta_area_um2', 'delta_leakage_TT_25C_RUN_mW',
    ]
    out_lines = []
    # Ensure header
    if lines and lines[0].startswith('metric,'):
        out_lines.append(lines[0])
    else:
        out_lines.append('metric,value')
    # Add known keys if present
    for k in order:
        if k in existing:
            out_lines.append(f"{k},{existing[k]}")
    # Add any remaining keys not in the preferred order
    for k, v in existing.items():
        if k not in order and k != 'metric':
            out_lines.append(f"{k},{v}")
    summary_path.write_text('\n'.join(out_lines) + '\n')


def main():
    ap = argparse.ArgumentParser(description="Append history and add trend deltas to summary")
    ap.add_argument('--timing', type=Path, required=True)
    ap.add_argument('--area', type=Path, required=True)
    ap.add_argument('--power', type=Path, required=True)
    ap.add_argument('--summary', type=Path, required=True)
    ap.add_argument('--history-dir', type=Path, required=True)
    args = ap.parse_args()

    timing_vals = parse_timing(args.timing)
    area_vals = parse_area(args.area)
    power_vals = parse_power_leakage(args.power)

    # Append histories
    t_row = append_history(args.history_dir / 'timing_history.csv', ['wns_ns', 'fmax_mhz'], timing_vals)
    a_row = append_history(args.history_dir / 'area_history.csv', ['area_um2'], area_vals)
    # Focus on TT_25C RUN leakage for delta
    p_row = append_history(
        args.history_dir / 'power_history.csv',
        ['leak_TT_25C_RUN', 'leak_TT_25C_SLEEP', 'leak_TT_25C_DEEP_SLEEP'],
        {
            'leak_TT_25C_RUN': power_vals.get('leak_TT_25C_RUN', ''),
            'leak_TT_25C_SLEEP': power_vals.get('leak_TT_25C_SLEEP', ''),
            'leak_TT_25C_DEEP_SLEEP': power_vals.get('leak_TT_25C_DEEP_SLEEP', ''),
        },
    )

    # Collect deltas for summary
    deltas = {}
    if isinstance(t_row.get('delta_wns_ns'), (float, int)):
        deltas['delta_wns_ns'] = t_row['delta_wns_ns']
    if isinstance(t_row.get('delta_fmax_mhz'), (float, int)):
        deltas['delta_fmax_mhz'] = t_row['delta_fmax_mhz']
    if isinstance(a_row.get('delta_area_um2'), (float, int)):
        deltas['delta_area_um2'] = a_row['delta_area_um2']
    if isinstance(p_row.get('delta_leak_TT_25C_RUN'), (float, int)):
        deltas['delta_leakage_TT_25C_RUN_mW'] = p_row['delta_leak_TT_25C_RUN']

    update_summary(args.summary, deltas)


if __name__ == '__main__':
    main()
