#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


def parse_wns_from_reports(reports_dir: Path) -> float | None:
    # Priority 1: report_wns.rpt or wns.rpt
    candidates = [
        *(reports_dir.glob("*report_wns*.rpt")),
        *(reports_dir.glob("*wns*.rpt")),
        *(reports_dir.glob("report_checks*.rpt")),
    ]
    for p in candidates:
        try:
            txt = p.read_text(errors="ignore")
        except Exception:
            continue
        # Common OpenSTA patterns
        for pat in [
            r"\bWNS\s*[:=]\s*(-?\d+\.\d+)",
            r"worst\s+slack\s*=\s*(-?\d+\.\d+)",
            r"slack\s*\(\w+\)\s*(-?\d+\.\d+)",
        ]:
            m = re.search(pat, txt, re.IGNORECASE)
            if m:
                try:
                    return float(m.group(1))
                except Exception:
                    pass
        # Fallback: scan all 'slack' values and take min
        vals = [
            float(x)
            for x in re.findall(r"slack\s*\(\w+\)\s*(-?\d+\.\d+)", txt, re.IGNORECASE)
        ]
        if vals:
            return min(vals)
    return None


def write_csv(out: Path, wns_ns: float, period_ns: float | None):
    out.parent.mkdir(parents=True, exist_ok=True)
    if period_ns is None:
        # Unknown clock period; we cannot compute fmax
        out.write_text(f"wns_ns,{wns_ns},fmax_mhz,NA\n")
        return
    # Rough fmax estimate: if WNS < 0, critical delay = period - wns
    crit_ns = period_ns - wns_ns
    if crit_ns <= 0:
        fmax_mhz = "NA"
    else:
        fmax_mhz = round(1000.0 / crit_ns, 3)
    out.write_text(f"wns_ns,{wns_ns},fmax_mhz,{fmax_mhz}\n")


def main():
    ap = argparse.ArgumentParser(description="Parse OpenSTA reports for WNS and estimate Fmax")
    ap.add_argument("--in", dest="in_dir", type=Path, required=True, help="Directory with OpenSTA .rpt files")
    ap.add_argument("--out", dest="out_csv", type=Path, required=True, help="Output CSV path (wns_fmax.csv)")
    ap.add_argument("--period-ns", dest="period_ns", type=float, default=None, help="Clock period in ns for Fmax estimate")
    args = ap.parse_args()

    wns = parse_wns_from_reports(args.in_dir)
    if wns is None:
        raise SystemExit(f"Could not find WNS in reports under {args.in_dir}")
    write_csv(args.out_csv, wns, args.period_ns)


if __name__ == "__main__":
    main()

