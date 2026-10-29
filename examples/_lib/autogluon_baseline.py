"""AutoGluon TabularPredictor baseline on exported CATS windows, compared with Kenning measurements.

usage: python -I autogluon_baseline.py <cats.npz> <out_dir> [--time-limit S] [--cpus N] [--kenning M.json ...]
Runs in the `autogluon` env (CPU only, no torch models). Each window (window x features) is flattened into one row.
Writes <out_dir>/compare.json and compare.md: accuracy and F1 (anomaly class) of AutoGluon and of each Kenning
measurements file (from its eval_confusion_matrix), plus model size. AutoGluon models are host-only: they have no
TFLite/microTVM export and are never deployed to an MCU.
"""
import argparse
import json
import os
from pathlib import Path


def dir_size(p: Path) -> int:
    return sum(f.stat().st_size for f in p.rglob("*") if f.is_file())


def scores(tn: int, fp: int, fn: int, tp: int) -> dict:
    tot = tn + fp + fn + tp
    prec = tp / (tp + fp) if tp + fp else 0.0
    rec = tp / (tp + fn) if tp + fn else 0.0
    f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
    return {"samples": tot, "accuracy": round((tn + tp) / tot, 4) if tot else None, "f1": round(f1, 4),
            "precision": round(prec, 4), "recall": round(rec, 4)}


def kenning_scores(path: Path) -> dict:
    d = json.loads(path.read_text())
    cm = d["eval_confusion_matrix"]          # rows: truth (normal, anomaly), columns: prediction
    r = scores(int(cm[0][0]), int(cm[0][1]), int(cm[1][0]), int(cm[1][1]))
    r.update(name=f"Kenning {path.stem.removeprefix('measurements_')}", model_bytes=d.get("compiled_model_size"), mcu_deployable=True)
    return r


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("npz", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--time-limit", type=int, default=60)
    ap.add_argument("--cpus", type=int, default=min(8, os.cpu_count() or 1))
    ap.add_argument("--kenning", type=Path, nargs="*", default=[])
    a = ap.parse_args()

    import numpy as np
    import pandas as pd
    from autogluon.tabular import TabularPredictor

    z = np.load(a.npz)
    def frame(x, y):
        df = pd.DataFrame(x.reshape(len(x), -1), columns=[f"f{i}" for i in range(x[0].size)])
        df["anomaly"] = y
        return df
    train, test = frame(z["X_train"], z["y_train"]), frame(z["X_test"], z["y_test"])
    a.out.mkdir(parents=True, exist_ok=True)
    pred = TabularPredictor(label="anomaly", eval_metric="f1", path=str(a.out / "ag_models"), verbosity=1).fit(
        train, time_limit=a.time_limit, presets="medium_quality", num_cpus=a.cpus, num_gpus=0,
        excluded_model_types=["NN_TORCH", "FASTAI", "CAT"])   # CPU, no torch or catboost: LightGBM, XGBoost, RF/XT, kNN, linear
    yp = pred.predict(test.drop(columns=["anomaly"])).to_numpy()
    yt = test["anomaly"].to_numpy()
    tp = int(((yp == 1) & (yt == 1)).sum()); tn = int(((yp == 0) & (yt == 0)).sum())
    fp = int(((yp == 1) & (yt == 0)).sum()); fn = int(((yp == 0) & (yt == 1)).sum())
    ag = scores(tn, fp, fn, tp)
    ag.update(name=f"AutoGluon {pred.model_best}", model_bytes=dir_size(a.out / "ag_models"), mcu_deployable=False)
    rows = [ag] + [kenning_scores(m) for m in a.kenning]
    pred.leaderboard(test, silent=True).to_csv(a.out / "leaderboard.csv", index=False)
    (a.out / "compare.json").write_text(json.dumps(rows, indent=2))
    lines = ["| model | test windows | accuracy | F1 (anomaly) | precision | recall | model size | MCU |",
             "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        size = r["model_bytes"]
        size = f"{size / 1024:.1f} KB" if size and size < 1 << 20 else (f"{size / (1 << 20):.1f} MB" if size else "-")
        lines.append(f"| {r['name']} | {r['samples']} | {r['accuracy']} | {r['f1']} | {r['precision']} | "
                     f"{r['recall']} | {size} | {'yes' if r['mcu_deployable'] else 'no (host only)'} |")
    (a.out / "compare.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
