"""Export the CATS anomaly-detection windows exactly as Kenning splits them (for host-side baselines).

usage: python -I cats_export.py <dataset_root> <out.npz> [--csv URI] [--test-fraction F] [--seed S] [--window W]
Uses kenning.datasets.anomaly_detection_dataset.AnomalyDetectionDataset (run in the `automl` env) with the same
csv/split/seed/window as the AutoML scenarios, so a host model (AutoGluon) sees the same train and test windows.
"""
import argparse
from pathlib import Path

import numpy as np
from kenning.datasets.anomaly_detection_dataset import AnomalyDetectionDataset
from kenning.utils.resource_manager import ResourceURI


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--csv", default="kenning:///datasets/anomaly_detection/cats_nano.csv")
    ap.add_argument("--test-fraction", type=float, default=0.1)
    ap.add_argument("--seed", type=int, default=12345)
    ap.add_argument("--window", type=int, default=5)
    a = ap.parse_args()
    ds = AnomalyDetectionDataset(a.root, csv_file=ResourceURI(a.csv), split_fraction_test=a.test_fraction,
                                 split_seed=a.seed, window_size=a.window)
    xtr, xte, ytr, yte = (np.asarray(v) for v in ds.train_test_split_representations()[:4])   # windows, labels
    np.savez(a.out, X_train=xtr.astype(np.float32), y_train=ytr.astype(np.int64),
             X_test=xte.astype(np.float32), y_test=yte.astype(np.int64), features=ds.num_features, window=a.window)
    print(f"CATS windows: train {len(xtr)} ({int(ytr.sum())} anomalous), test {len(xte)} ({int(yte.sum())} anomalous), "
          f"{ds.num_features} features x window {a.window} -> {a.out.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
