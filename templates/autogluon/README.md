# @NAME@: AutoGluon host baseline

Made by `kenning-box new autogluon @NAME@`. [AutoGluon](https://auto.gluon.ai/stable/index.html) 1.6.3
`TabularPredictor` (LightGBM, XGBoost, random forest / extra trees, kNN, linear; no torch models, CPU only, 60 s) on
the CATS anomaly windows exactly as Kenning splits them (`examples/_lib/cats_export.py`). Pass Kenning measurements
files to compare: `./run.sh path/to/measurements.json` (e.g. from `kenning-box new automl`).
Output: `build/@NAME@/compare.md` (accuracy, F1 of the anomaly class, model size), `leaderboard.csv`, `ag_models/`.

**AutoGluon models are not deployable to MCUs**: no TFLite or microTVM export, megabytes of Python/C++ models.
Use them as a host-side baseline for what an MCU model (Kenning AutoML within a RAM budget) gives up.

| setting | here | swap for |
|---|---|---|
| `seconds` in run.sh | 60 | longer = more models in the ensemble |
| data | CATS nano via Kenning's dataset class | `cats_export.py --csv <URI or path>` |

Run: `./run.sh` or `./run.sh --dry-run`. Needs `kenning-box extra install automl autogluon`.
