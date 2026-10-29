# @NAME@: weight clustering

Made by `kenning-box new clustering @NAME@`. Each weight tensor is reduced to `clusters_number` shared values (TF Model Optimization), fine-tuned, then converted.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `TensorFlowClusteringOptimizer` (16 clusters) -> TFLite fp32 | `clusters_number`, `cluster_dense`, `preserve_sparsity`; TFLite `int8` |
| `runtime` | `TFLiteRuntime` | - |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run tflite_clustering`).
