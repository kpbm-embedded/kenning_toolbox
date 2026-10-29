"""Summarize (and check) Kenning measurements JSON files.

usage: python -I summarize.py [--min-accuracy A] [--out summary.json] m1.json [m2.json ...]
Prints accuracy, mean/median inference time per sample, model size; exits 1 when a file is
missing, has no inferences, or is below --min-accuracy.
"""
import argparse
import json
import statistics
import sys
from pathlib import Path


def summarize(path: Path) -> dict:
    d = json.loads(path.read_text())
    cm = d.get("eval_confusion_matrix") or []
    total = int(sum(sum(r) for r in cm))
    correct = float(sum(cm[i][i] for i in range(len(cm)))) if cm else 0.0
    t = d.get("target_inference_step") or d.get("protocol_inference_step") or []  # protocol_*: round trip to a server/board
    return {
        "file": str(path),
        "optimizers": [o.get("compiler_framework", o.get("type", "?")) if isinstance(o, dict) else str(o)
                       for o in d.get("optimizers", [])],
        "samples": total,
        "accuracy": round(correct / total, 4) if total else None,
        "inference_ms_mean": round(1000 * statistics.mean(t), 4) if t else None,
        "inference_ms_median": round(1000 * statistics.median(t), 4) if t else None,
        "model_size_bytes": d.get("compiled_model_size"),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-accuracy", type=float, default=0.0)
    ap.add_argument("--out")
    ap.add_argument("files", nargs="+", type=Path)
    a = ap.parse_args()
    rows, bad = [], 0
    for f in a.files:
        if not f.is_file():
            print(f"FAIL  {f}: missing"); bad += 1; continue
        s = summarize(f)
        rows.append(s)
        ok = s["samples"] > 0 and (s["accuracy"] or 0) >= a.min_accuracy
        bad += 0 if ok else 1
        print(f"{'ok  ' if ok else 'FAIL'}  {f.name:28s} samples={s['samples']:4d} accuracy={s['accuracy']} "
              f"inference_ms mean={s['inference_ms_mean']} median={s['inference_ms_median']} size={s['model_size_bytes']}")
    if a.out:
        Path(a.out).write_text(json.dumps(rows, indent=2) + "\n")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
