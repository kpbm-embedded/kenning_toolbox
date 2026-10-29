# @NAME@: optimizer/runtime grid search

Made by `kenning-box new optimizer_search @NAME@`. Every list value is a search dimension; Kenning runs each valid optimizer chain + runtime and keeps the best by `metric`.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimization_parameters` | grid search, minimise `inferencetime_mean` | `policy: max` with `accuracy`, `compiled_model_size` |
| `optimizers`, `runtime` | TFLite fp32/int8, TFLite -> TVM | more targets, `IREECompiler`, `ONNXCompiler` |

Run:

```sh
./run.sh               # all pipelines, best one in build/@NAME@_best.json
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run optimizer_search`).
