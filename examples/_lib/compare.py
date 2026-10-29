"""Markdown comparison report of several Kenning measurements files (no `reports` extra needed).

usage: python -I compare.py --out report.md [--baseline LABEL] LABEL=measurements.json [LABEL=m2.json ...]
One row per pipeline: accuracy, mean/median inference time, model size, and the speed-up and size ratio
against the baseline (default: the first one). Exits 1 when a file is missing or has no inferences.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from summarize import summarize  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--baseline")
    ap.add_argument("runs", nargs="+")
    a = ap.parse_args()
    rows = {}
    for r in a.runs:
        label, _, f = r.partition("=")
        p = Path(f)
        if not p.is_file():
            print(f"FAIL  {label}: {f} missing"); return 1
        s = summarize(p)
        if not s["samples"]:
            print(f"FAIL  {label}: no inferences in {f}"); return 1
        rows[label] = s
    base = rows[a.baseline or next(iter(rows))]
    lines = ["| Pipeline | Accuracy | Mean ms | Median ms | Size KB | Speed-up (median) | Size ratio |",
             "|---|---|---|---|---|---|---|"]
    for label, s in rows.items():
        sp = base["inference_ms_median"] / s["inference_ms_median"] if s["inference_ms_median"] else 0
        size = f"{s['model_size_bytes'] / 1024:.1f}" if s["model_size_bytes"] else "-"
        ratio = f"{s['model_size_bytes'] / base['model_size_bytes']:.2f}" if s["model_size_bytes"] and base["model_size_bytes"] else "-"
        lines.append(f"| {label} | {s['accuracy']:.4f} | {s['inference_ms_mean']:.4f} | {s['inference_ms_median']:.4f} "
                     f"| {size} | {sp:.2f}x | {ratio} |")
    best = min(rows, key=lambda k: rows[k]["inference_ms_median"])
    small = min((k for k in rows if rows[k]["model_size_bytes"]), key=lambda k: rows[k]["model_size_bytes"], default="-")
    text = (f"# Pipeline comparison ({base['samples']} test samples, baseline {a.baseline or next(iter(rows))})\n\n"
            + "\n".join(lines) + f"\n\nFastest (median): **{best}**. Smallest model: **{small}**.\n")
    Path(a.out).write_text(text)
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
